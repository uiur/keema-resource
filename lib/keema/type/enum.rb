module Keema
  module Type
    class Enum
      attr_reader :values
      def initialize(values)
        @values = values
      end

      def to_json_schema(openapi: false)
        result = ::Keema::JsonSchema.convert_type(values.first.class, openapi: openapi)
        result[:enum] = values
        result
      end
    end
  end
end
