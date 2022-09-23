module Keema
  module Type
    class Nullable
      attr_reader :type
      def initialize(type)
        @type = type
      end

      def to_json_schema(openapi: false)
        hash = ::Keema::JsonSchema.convert_type(type, openapi: openapi)
        if openapi
          hash[:nullable] = true
        else
          hash[:type] = [hash[:type], :null]
        end
        hash
      end
    end
  end
end
