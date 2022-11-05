# frozen_string_literal: true
require 'json'

def debug(*data)
  if ENV['DEBUG']
    require 'irb/color_printer'
    data.each do |row|
      ::IRB::ColorPrinter.pp(row)
    end
  end
end

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
      context 'valid' do
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
        end
      end

      context 'invalid' do
        InvalidProduct = Struct.new(:id, :name, keyword_init: true)

        it do
          invalid_product = InvalidProduct.new(id: 1, name: 'foo')
          expect {
            ProductResource.serialize(invalid_product)
          }.to raise_error(::Keema::Resource::RuntimeError)
        end
      end
    end

    describe '.to_json_schema' do
      context 'default' do
        it 'generates json schema' do
          debug ProductResource.to_json_schema
          expect(ProductResource.to_json_schema).to match(
            title: 'ProductResource',
            type: :object,
            properties: {
              id: { type: :integer },
              name: { type: :string },
              price: { type: :number },
              status: { type: :string, enum: [:published, :unpublished] },
              description: { type: [:string, :null] },
              image_url: { type: :string },
              out_of_stock: { type: :boolean },
              tags: { type: :array, items: { type: :string } },
              created_at: { type: :string, format: :'date-time' }
            },
            additionalProperties: false,
            required: [
              :id,
              :name,
              :price,
              :status,
              :description,
              # :image_url is optional
              :out_of_stock,
              :tags,
              :created_at,
          ])
        end
      end

      context 'select' do
        it 'generates json schema' do
          debug ProductResource.select([:id, :name]).to_json_schema
          expect(ProductResource.select([:id, :name]).to_json_schema).to match(
            title: 'ProductResource',
            type: :object,
            properties: {
              id: { type: :integer },
              name: { type: :string },
            },
            additionalProperties: false,
            required: [
              :id,
              :name,
            ]
          )
        end
      end

      context 'fields are all optional' do
        class OptionalProductResource < Keema::Resource
          field :name, String, optional: true
          field :description, String, optional: true
        end

        subject(:schema) { OptionalProductResource.to_json_schema }

        it 'generates schema without required' do
          expect(schema).to match(hash_including(
            type: :object,
            properties: {
              name: { type: :string },
              description: { type: :string },
            },
            additionalProperties: false
          ))

          expect(schema).not_to have_key(:required)
        end
      end
    end

    describe '.to_openapi' do
      it 'generetes openapi schema' do
        debug ProductResource.to_openapi
        expect(ProductResource.to_openapi).to match(
          title: 'ProductResource',
          type: :object,
          properties: {
            id: { type: :integer },
            name: { type: :string },
            price: { type: :number },
            status: { type: :string, enum: [:published, :unpublished] },
            description: { type: :string, nullable: true },  # openapi uses nullable keyword
            image_url: { type: :string },
            out_of_stock: { type: :boolean },
            tags: { type: :array, items: { type: :string } },
            created_at: { type: :string, format: :'date-time' }
          },
          additionalProperties: false,
          required: [
            :id,
            :name,
            :price,
            :status,
            :description,
            # :image_url is optional
            :out_of_stock,
            :tags,
            :created_at,
        ])
      end
    end

    describe '.select' do
      context 'select optional field' do
        subject(:resource) { ProductResource.select([:id, :image_url]) }
        it 'returns the field as required' do
          expect(resource.to_json_schema).to match(hash_including(
            type: :object,
            properties: {
              id: { type: :integer },
              image_url: { type: :string }
            },
            required: [:id, :image_url],
          ))
          expect(resource.serialize(product)).to match(
            id: Integer,
            image_url: String,
          )
        end
      end

      context 'select required field' do
        subject(:resource) { ProductResource.select([:id, :name]) }
        it 'returns select resource class' do
          expect(resource.to_json_schema).to match(hash_including(
            type: :object,
            properties: {
              id: { type: :integer },
              name: { type: :string },
            },
            required: [:id, :name],
          ))
          expect(resource.serialize(product)).to match(
            id: Integer,
            name: String
          )
        end
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
        context 'default schema' do
          it 'returns json schema hash' do
            debug NestedHasMany::ProductResource.to_json_schema
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

        context 'selected schema' do
          subject(:schema) { NestedHasMany::ProductResource.select([:id, product_images: [:id]]).to_json_schema }

          it do
            debug schema
            expect(schema).to match(hash_including(
              type: :object,
              properties: hash_including(
                id: Hash,
                product_images: hash_including(
                  type: :array,
                  items: hash_including(
                    type: :object,
                    properties: hash_including(
                      id: Hash,
                    ),
                    required: [:id]
                  )
                )
              )
            ))
          end
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
