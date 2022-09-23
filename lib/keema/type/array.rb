module Keema
  module Type
    class Array
      attr_reader :type
      def initialize(type)
        @type = type
      end

      def to_json_schema(openapi: false)
        { type: :array, items: ::Keema::JsonSchema.convert_type(type, openapi: openapi) }
      end
    end
  end
end
