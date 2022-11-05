require_relative 'json_schema'
require_relative 'type'

module Keema
  class Field
    attr_reader :name, :type, :null, :optional, :default, :options
    attr_writer :type
    def initialize(name:, type:, null: false, optional: false, default: nil, **options)
      parsed_name, parsed_optional = parse_name(name)
      @name = parsed_name
      @type = type
      @null = null
      @optional = parsed_optional || optional
      @default = default
      @options = options
    end

    def to_json_schema(openapi: false)
      field_type = null ? ::Keema::Type::Nullable.new(type) : type
      ::Keema::JsonSchema.convert_type(field_type, openapi: openapi).merge(options)
    end

    private

    def parse_name(name)
      is_optional = name.end_with?('?')
      real_name = is_optional ? name[0..-2] : name

      [real_name.to_sym, is_optional]
    end
  end
end
