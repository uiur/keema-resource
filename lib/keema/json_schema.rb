module Keema
  class JsonSchema
    def self.convert_type(type, openapi: false)
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
      when type.is_a?(Array)
        ::Keema::Type::Array.new(type.first).to_json_schema(openapi: openapi)
      when type.respond_to?(:to_json_schema)
        type.to_json_schema(openapi: openapi)
      else
        raise "Converting type #{type} into json schema is not supported"
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
