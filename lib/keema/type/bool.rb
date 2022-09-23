module Keema
  module Type
    class Bool
      def self.to_json_schema(*)
        { type: :boolean }
      end
    end
  end
end
