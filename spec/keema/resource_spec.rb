# frozen_string_literal: true
require 'json'

RSpec.describe Keema::Resource do
  it "has a version number" do
    expect(Keema::Resource::VERSION).not_to be nil
  end

  describe 'flat resource' do
    class ProductResource < Keema::Resource
      field :id, Integer
      field :name, String
      field :price, Float
      field :status, enum(:published, :unpublished)
      field :description, String, null: true
      field :image_url?, String

      field :out_of_stock, Bool
      field :tags, [String]

      field :created_at, Time
    end

    Product = Struct.new(*ProductResource.fields.keys, keyword_init: true)

    let(:product) do
      Product.new(
        id: 1,
        name: "foo",
        status: 'published',
        price: 12.3,
        description: nil,
        out_of_stock: false,
        tags: ['food', 'sushi'],
        image_url: 'foo.png',
        created_at: Time.now
      )
    end

    describe '#serialize' do
      it 'returns serializable hash' do
        hash = ProductResource.serialize(product)
        expect(hash).to match(
          id: 1,
          name: 'foo',
          status: 'published',
          price: 12.3,
          description: nil,
          out_of_stock: false,
          tags: ['food', 'sushi'],
          created_at: String
        )
        pp hash
      end
    end

    describe '.to_json_schema' do
      it 'generetes json schema' do
        expect(ProductResource.to_json_schema).to match(
          title: 'ProductResource',
          type: :object,
          properties: Hash,
          additionalProperties: false,
          required: Array
        )
        expect(ProductResource.to_json_schema(openapi: true)).to match(Hash)
        puts JSON.pretty_generate(ProductResource.to_json_schema)
        puts JSON.pretty_generate(ProductResource.to_json_schema(use_ref: true))
      end
    end

    describe '.select' do
      it 'returns select resource class' do
        select_resource_klass = ProductResource.select([:id, :name])
        expect(select_resource_klass.to_json_schema).to match(Hash)
        expect(select_resource_klass.serialize(product)).to match(
          id: Integer,
          name: String
        )
      end
    end
  end

  describe 'define methods in class' do
    module DefineMethod
      require 'securerandom'
      class ProductResource < Keema::Resource
        field :id, String
        field :hex, String

        def id
          "id-#{object.id}"
        end

        def hex
          SecureRandom.hex
        end
      end
      Product = Struct.new(:id, keyword_init: true)
    end

    it do
      expect(
        DefineMethod::ProductResource.select([:id])
          .serialize(DefineMethod::Product.new(id: 1234))
      ).to match(id: 'id-1234')
    end
  end

  describe 'nested resource with has-many relationships' do
    module NestedHasMany
      class ProductImageResource < Keema::Resource
        field :id, Integer
        field :url, String
      end

      class ProductResource < Keema::Resource
        field :id, Integer
        field :product_images, [ProductImageResource]
      end

      Product = Struct.new(:id, :product_images, keyword_init: true)
      ProductImage = Struct.new(:id, :url, keyword_init: true)
    end

    context 'resource has many resources' do
      let(:product_images) { [NestedHasMany::ProductImage.new(id: 1, url: '/foo.png'), NestedHasMany::ProductImage.new(id: 2, url: '/bar.png')] }
      let(:product) { NestedHasMany::Product.new(id: 1, product_images: product_images) }

      describe 'to_json_schema' do
        it 'returns json schema hash' do
          puts JSON.pretty_generate(NestedHasMany::ProductResource.to_json_schema)
          expect(NestedHasMany::ProductResource.to_json_schema).to match(hash_including(
            type: :object,
            properties: hash_including(
              product_images: hash_including(
                type: :array,
                items: hash_including(
                  type: :object,
                  properties: hash_including(
                    id: Hash,
                    url: Hash
                  )
                )
              )
            )
          ))
        end
      end

      describe 'to_json_schema(use_ref: true)' do
        it 'returns NestedHasMany resource as reference' do
          puts JSON.pretty_generate(NestedHasMany::ProductResource.to_json_schema(use_ref: true))
          expect(NestedHasMany::ProductResource.to_json_schema(use_ref: true)).to match(hash_including(
            type: :object,
            properties: hash_including(
              product_images: hash_including(
                type: :array,
                items: hash_including(
                  tsType: String
                )
              )
            )
          ))
        end
      end

      describe 'serialize' do
        it 'returns serialized hash' do
          expect(NestedHasMany::ProductResource.serialize(product)).to match(
            id: Integer,
            product_images: [
              { id: Integer, url: String },
              { id: Integer, url: String }
            ]
          )
        end
      end

      describe 'serialize selected resource' do
        it 'returns serialized hash partially' do
          expect(
            NestedHasMany::ProductResource
              .select([
                :id,
                product_images: [:id]
              ])
              .serialize(product)
          ).to match(
            id: Integer,
            product_images: [
              { id: Integer },
              { id: Integer }
            ]
          )
        end
      end
    end

    context 'resource has empty array for relationship' do
      let(:product) { NestedHasMany::Product.new(id: 1, product_images: []) }

      describe 'serialize' do
        it 'returns serialized hash with empty array' do
          expect(NestedHasMany::ProductResource.serialize(product)).to match(
            id: Integer,
            product_images: []
          )
        end
      end
    end
  end

  describe 'nested resource with has-one relationships' do
    module NestedHasOne
      class ProductImageResource < Keema::Resource
        field :id, Integer
        field :url, String
      end

      class ProductResource < Keema::Resource
        field :id, Integer
        field :product_image, ProductImageResource
      end

      Product = Struct.new(:id, :product_image, keyword_init: true)
      ProductImage = Struct.new(:id, :url, keyword_init: true)
    end

    context 'it has object as relationship' do
      let(:product) { NestedHasOne::Product.new(id: 1, product_image: product_image) }
      let(:product_image) { NestedHasOne::ProductImage.new(id: 1, url: '/foo.png') }

      it do
        expect(NestedHasOne::ProductResource.serialize(product)).to match(
          id: Integer,
          product_image: { id: Integer, url: String }
        )
      end
    end

    context 'it has nil as relationship' do
      let(:product) { NestedHasOne::Product.new(id: 1, product_image: nil) }

      it do
        expect(NestedHasOne::ProductResource.serialize(product)).to match(
          id: Integer,
          product_image: nil
        )
      end
    end
  end
end
