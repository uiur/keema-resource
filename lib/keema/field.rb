require_relative 'json_schema'
require_relative 'type'

module Keema
  class Field
    attr_reader :name, :type, :null, :optional
    attr_writer :type
    def initialize(name:, type:, null: false, optional: false)
      parsed_name, parsed_optional = parse_name(name)
      @name = parsed_name
      @type = convert_type(type)
      @null = null
      @optional = parsed_optional || optional
    end

    def convert_type(type)
      if type.is_a?(Hash) && type[:enum]
        ::Keema::Type::Enum.new(type[:enum])
      else
        type
      end
    end

    def to_json_schema(openapi: false)
      field_type = null ? ::Keema::Type::Nullable.new(type) : type
      ::Keema::JsonSchema.convert_type(field_type, openapi: openapi)
    end

    def item_type
      type.is_a?(Array) ? type.first : type
    end

    private

    def parse_name(name)
      is_optional = name.end_with?('?')
      real_name = is_optional ? name[0..-2] : name

      [real_name.to_sym, is_optional]
    end
  end
end
