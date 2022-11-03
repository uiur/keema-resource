# frozen_string_literal: true

RSpec.describe Keema::Parameters do
  describe '.to_openapi' do
    class CreateRestaurantParameters < Keema::Parameters
      field :id, Integer, in: :path
      field :name, String, in: :body
      field :address, String, in: :body, optional: true, null: true
      field :genre, enum('Sushi', 'Ramen'), in: :body, description: 'genre of food', example: 'Sushi'
    end

    it 'returns openapi parameter objects as hash' do
      expect(CreateRestaurantParameters.to_openapi).to match([
        hash_including(name: :id, in: :path, schema: { type: :integer }, required: true),
        hash_including(name: :name, in: :body, schema: { type: :string }, required: true),
        hash_including(name: :address, in: :body, schema: { type: :string, nullable: true }, required: false),
        hash_including(name: :genre, in: :body, schema: { type: :string, enum: ['Sushi', 'Ramen'] }, required: true, description: 'genre of food')
      ])
    end
  end

  class PaginationParameters < Keema::Parameters
    field :page, Integer
    field :per_page, Integer
  end

  describe PaginationParameters do
    describe 'getters' do
      subject(:params) do
        PaginationParameters.new({
          page: 1,
          per_page: 20
        })
      end

      it 'returns value' do
        expect(params.page).to eq(1)
        expect(params.per_page).to eq(20)
      end
    end

    describe '#to_h' do
      context 'valid' do
        subject(:params) do
          PaginationParameters.new({
            page: 1,
            per_page: 20
          })
        end

        it 'returns values as hash' do
          expect(params.to_h).to match({
            page: 1,
            per_page: 20
          })
        end
      end

      context 'input has extra parameters' do
        subject(:params) do
          PaginationParameters.new({
            page: 1,
            per_page: 20,
            foo: 'bar'
          })
        end

        it 'only returns values specified in parameters' do
          expect(params.to_h).to match({
            page: 1,
            per_page: 20
          })
        end
      end
    end

  end

  class PaginationWithDefaultParameters < Keema::Parameters
    field :page, Integer, default: 1
    field :per_page, Integer, default: 20
  end

  describe PaginationWithDefaultParameters do
    context 'parameter is not specified' do
      subject(:params) do
        PaginationWithDefaultParameters.new({
          page: 2,
          per_page: nil
        })
      end

      describe 'getter' do
        it 'returns default value if input is nil' do
          expect(params.page).to eq(2)
          expect(params.per_page).to eq(20)
        end
      end
    end
  end
end
