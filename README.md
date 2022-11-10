# keema-resource ![test](https://github.com/uiur/keema-resource/actions/workflows/main.yml/badge.svg)

keema-resource is a JSON object presenter with the power of generating JSON Schema / OpenAPI 3.0 Schema.
It provides minimalistic-style DSL to describe JSON Schema.

It's intended to be used as an alternative to active_model_serializers or jbuilder.

## Overview

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

# Generate json schema
ProductResource.to_json_schema

# Generate openapi-compatible json schema
ProductResource.to_openapi
```

## JSON serialization
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

### Selecting fields
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

### Nested resource
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

### Adding methods
You can add methods in resource class and override the behavior of the original object.

```ruby
require 'securerandom'
class ProductResource < Keema::Resource
  field :id, String
  field :hex, String

  def id
    # object is the original object (`product` in here)
    "product-#{object.id}"
  end

  def hex
    SecureRandom.hex
  end
end

Product = Struct.new(:id, keyword_init: true)
product = Product.new(id: 1234)

ProductResource.serialize(product)
#=> {:id=>"product-1234", :hex=>"71ab70d16b5b0801357a6c088abdbac2"}
```

### Lazy evaluation
Only selected fields are rendered. It doesn't evaluate unnecessary fields.

It helps to avoid performance problems such as N+1.

For example:

```ruby
class ProductResource < Keema::Resource
  field :id, String
  field :fast, String
  field :slow, String

  def fast
    'fast'
  end

  def slow
    sleep 10 && 'slow'
  end
end

Product = Struct.new(:id, keyword_init: true)
product = Product.new(id: 1234)

ProductResource.serialize(product, fields: [
  :id, :fast
])
#=> {:id=>1234, :fast=>"fast"}
# It returns data with no problem.
# Only selected fields are rendered. The slow field is not evaluated.
```

### Using context
In some cases, you may need to use context other than an object. (e.g. current_user etc.)

`serialize` method can take context hash as an option. Context can be accessed from methods.


```ruby
class PostResource < Keema::Resource
  field :id, Integer
  field :title, String
  field :editable, Bool

  def editable
    context[:current_user].post_ids.include?(object.id)
  end
end

User = Struct.new(:post_ids, keyword_init: true)
Post = Struct.new(:id, :title, keyword_init: true)

current_user = User.new(post_ids: [1])
post = Post.new(id: 1, title: 'foo')

PostResource.serialize(post, context: {
  current_user: current_user
})
#=> {:id=>1, :title=>"foo", :editable=>true}
```

Also, context hash is passed into nested resources.

```ruby
class UserResource < Keema::Resource
  field :id, Integer
  field :posts, [PostResource]
end

user = OpenStruct.new(id: 2, posts: [post])
UserResource.serialize(user, context: {
  current_user: current_user
})
#=> {:id=>2, :posts=>[{:id=>1, :title=>"foo", :editable=>true}]}
```

## Schema generation
It can generate JSON Schema and OpenAPI schema with `.to_openapi` and `.to_json_schema`.

```ruby
class ProductResource < Keema::Resource
  field :id, Integer
  field :name, String
  field :price, Float
  field :created_at, Time
end

ProductResource.to_openapi
#=>
# {
#   title: 'ProductResource',
#   type: :object,
#   properties: {
#     id: { type: :integer },
#     name: { type: :string },
#     price: { type: :number },
#     created_at: { type: :string, format: :'date-time' }
#   },
#   additionalProperties: false,
#   required: [
#     :id,
#     :name,
#     :price,
#     :created_at,
#   ]
# }
```

### Selecting schema fields
`.select(fields)` method creates a subset of a resource. Selected fields are specified as required.

```ruby
ProductResource.select([:id, :name]).to_openapi
#=>
# {
#   type: :object,
#   properties: {
#     id: { type: :integer },
#     name: { type: :string },
#   },
#   additionalProperties: false,
#   required: [
#     :id,
#     :name
#   ]
# }
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'keema-resource', github: 'uiur/keema-resource'
```

And then execute:

    $ bundle install
## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/uiur/keema-resource. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/uiur/keema-resource/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Keema::Resource project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/uiur/keema-resource/blob/main/CODE_OF_CONDUCT.md).
