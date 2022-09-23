module Keema
  class JsonSchema
    attr_reader :openapi, :use_ref, :depth
    def initialize(openapi: false, use_ref: false, depth: 0)
      @openapi = openapi
      @use_ref = use_ref
      @depth = depth
    end

    def convert_type(type, nullable: false)
      hash = convert_real_type(type)
      if nullable
        if openapi
          hash[:nullable] = true
        else
          hash[:type] = [hash[:type], :null]
        end
      end
      hash
    end

    def convert_real_type(type)
      case
      when type == Integer
        { type: :integer }
      when type == Float
        { type: :number }
      when type == String || type == Symbol
        { type: :string }
      when type == Date
        { type: :string, format: :date }
      when type == Time
        { type: :string, format: :'date-time' }
      when type == ::Keema::Type::Bool
        { type: :boolean }
      when type.is_a?(::Keema::Type::Enum)
        result = convert_type(type.values.first.class)
        result[:enum] = type.values
        result
      when type.is_a?(Array)
        item_type = type.first
        { type: :array, items: convert_type(item_type) }
      when type.respond_to?(:is_keema_resource_class?)
        type = type.is_a?(::Class) ? type.new : type
        if depth > 0 && use_ref
          {
            tsType: type.ts_type,
            tsTypeImport: self.class.underscore(type.ts_type),
          }
        else
          {
            title: type.ts_type,
            type: :object,
            properties: type.fields.map do |name, field|
              [
                name, ::Keema::JsonSchema.new(openapi: openapi, use_ref: use_ref, depth: depth + 1).convert_type(field.type, nullable: field.null),
              ]
            end.to_h,
            additionalProperties: false,
            required: type.fields.values.map(&:name),
          }
        end
      else
        raise "unsupported type #{type}"
      end
    end

    def self.underscore(camel_cased_word)
      return camel_cased_word unless /[A-Z-]|::/.match?(camel_cased_word)
      word = camel_cased_word.to_s.gsub("::", "/")
      # word.gsub!(inflections.acronyms_underscore_regex) { "#{$1 && '_' }#{$2.downcase}" }
      word.gsub!(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
      word.tr!("-", "_")
      word.downcase!
      word
    end
  end
end
