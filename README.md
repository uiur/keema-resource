# keema-resource ![test](https://github.com/uiur/keema-resource/actions/workflows/main.yml/badge.svg)

keema-resource is a JSON object presenter with the capability of generating JSON Schema / OpenAPI Schema.
It provides minimalistic-style DSL to describe JSON Schema.

It's intended to be used as an alternative to active_model_serializers or jbuilder.

## Usage

```ruby
class ProductResource < Keema::Resource
  field :id, Integer
  field :name, String
  field :price, Float
  field :status, enum(:published, :unpublished)
  field :description, String, null: true
  field :image_url, String, optional: true

  field :out_of_stock, Bool
  field :tags, [String]

  field :created_at, Time
end

# Generate json schema
ProductResource.to_json_schema

# Generate json schema (openapi compatible)
ProductResource.to_openapi

# Serialize object to json representation
product = Product.new(
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
ProductResource.serialize(product)
#=>
# {
#   id: 1,
#   name: "foo",
#   price: 12.3,
#   status: "published",
#   description: nil,
#   out_of_stock: false,
#   tags: ["food", "sushi"],
#   created_at: "2022-11-04T09:49:30.297+09:00"
# }
```

## Feature
### JSON serialization
`.serialize` method serializes an object to a JSON serializable hash.
It acts as an object presenter.

For example:

```ruby
class ProductResource < Keema::Resource
  field :id, Integer
  field :name, String
  field :price, Float
end

# `serialize` method takes an object.
ProductResource.serialize(product)
#=>
# {
#   id: 1,
#   name: "foo",
#   price: 10.0
# }

# Also, it can take an array of objects. It returns output as an array.
ProductResource.serialize(products)
#=>
# [
#   {
#     id: 1,
#     name: 'foo',
#     price: 10.0
#   },
#   {
#     id: 2,
#     name: 'bar',
#     price: 20.0
#   }
# ]
```

In Rails, you can use the resource in action like this:

```ruby
def index
  products = Product.order(:id).limit(20)
  render json: ProductResource.serialize(products)
end
```

#### Selecting fields
By default, `serialize` renders all of not-optional fields.

```ruby
class ProductResource < Keema::Resource
  field :id, Integer  # default is optional: false
  field :name, String
  field :price, Float
  field :description, String, optional: true
end
ProductResource.serialize(products)
#=>
# [
#   {
#     id: 1,
#     name: "foo",
#     price: 10.0
#   }
# ]
```

To include optional fields, you need to specify them in fields option explicitly:

```ruby
ProductResource.serialize(products, fields: [
  :*, # `*` means all of not-optional fields
  :description
])
#=>
# [
#   {
#     id: 1,
#     name: "foo",
#     price: 10.0,
#     description: 'long product description'
#   }
# ]
```

In some cases, you may want to render only partial fields because of performance reason etc.

```ruby
ProductResource.serialize(products, fields: [
  :id,
  :name,
])
#=>
# [
#   {
#     id: 1,
#     name: 'foo',
#   },
#   {
#     id: 2,
#     name: 'bar',
#   }
# ]
```

#### Nested resource
It can render nested objects by specifying another resource in field type.

For example, when an object has has-many associations,

```ruby
class ProductResource < Keema::Resource
  field :id, Integer
  field :name, String
  field :product_images, [ProductImageResource]  # `[A]` means Array of A
end

class ProductImageResource < Keema::Resource
  field :id, Integer
  field :url, String
end

ProductResource.serialize(products)
#=>
# {
#   id: 1,
#   name: 'foo',
#   product_images: [
#     { id: 1, url: 'foo.png' },
#     { id: 2, url: 'bar.png' },
#   ]
# }
```

Also, it can select partial fields of nested resource.

```ruby
ProductResource.serialize(products, fields: [
  :id,
  :name,
  product_images: [:id]  # nested fields can be specified with hash form
])
```

### Schema generation
It can generate JSON Schema and OpenAPI schema with `.to_openapi` and `.to_json_schema`.

```ruby
class ProductResource < Keema::Resource
  field :id, Integer
  field :name, String
  field :price, Float
  field :created_at, Time
end

ProductResource.to_openapi
```


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'keema-resource'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install keema-resource

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/uiur/keema-resource. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/uiur/keema-resource/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Keema::Resource project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/uiur/keema-resource/blob/main/CODE_OF_CONDUCT.md).
