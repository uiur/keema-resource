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
  field :image_url?, String  # optional

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
#   :id => 1,
#   :name => "foo",
#   :price => 12.3,
#   :status => "published",
#   :description => nil,
#   :out_of_stock => false,
#   :tags => ["food", "sushi"],
#   :created_at => "2022-11-04T09:49:30.297+09:00"
# }
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

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/keema-resource. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/keema-resource/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Keema::Resource project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/keema-resource/blob/main/CODE_OF_CONDUCT.md).
