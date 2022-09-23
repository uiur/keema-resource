module Keema
  class Resource; end
  class Resource::FieldSelector
    attr_reader :selector, :resource
    def initialize(resource:, selector:)
      @resource = resource
      @selector = selector
    end

    def field_names
      selector.reduce([]) do |result, item|
        if item.is_a?(Hash)
          result += item.keys
        else
          if item == :*
            result += resource.fields.values.reject(&:optional).map(&:name)
          else
            result += [item]
          end
        end
      end
    end

    def fetch(name)
      nested_map[name] || [:*]
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
