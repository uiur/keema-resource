module Keema
  class Resource; end
  class Resource::FieldSelector
    attr_reader :selector, :default_field_names
    def initialize(default_field_names:, selector:)
      @default_field_names = default_field_names
      @selector = selector
    end

    def field_names
      selector.reduce([]) do |result, item|
        if item.is_a?(Hash)
          result += item.keys
        else
          if item == :*
            result += default_field_names
          else
            result += [item]
          end
        end
      end
    end

    def fetch(name)
      nested_map[name]
    end

    def nested_map
      if selector[-1]&.is_a?(Hash)
        selector[-1]
      else
        {}
      end
    end
  end
end
