module Keema
  class Parameters
    class Parameter
      attr_reader :field, :default
      def initialize(field:, in:, default: nil, options: {})
        @field = field
        @location_in = binding.local_variable_get(:in)
        @default = default
        @options = options
      end

      def name
        field.name
      end

      def to_openapi
        {
          name: name,
          schema: field.to_json_schema(openapi: true),
          in: location_in,
          required: required?
        }.merge(options)
      end

      private
      attr_reader :location_in, :options

      def required?
        if location_in == :path
          # If the parameter location is "path", this property is REQUIRED and its value MUST be true.
          true
        else
          !field.optional
        end
      end
    end

    class <<self
      attr_reader :parameters
      def field(name, type, in: :query, null: false, optional: false, default: nil, **options)
        @parameters ||= {}
        field = ::Keema::Field.new(name: name, type: type, null: null, optional: optional)
        parameter = ::Keema::Parameters::Parameter.new(
          field: field,
          in: binding.local_variable_get(:in),
          default: default,
          options: options
        )
        @parameters[parameter.name] = parameter
        define_parameter_getter(parameter)
      end

      def enum(*values)
        ::Keema::Type::Enum.new(values)
      end

      def to_openapi
        parameters.map do |_, parameter|
          parameter.to_openapi
        end
      end

      private

      def define_parameter_getter(parameter)
        define_method(parameter.name) do
          object[parameter.name] || parameter.default
        end
      end
    end

    # object is a hash-like object
    attr_reader :object
    def initialize(object)
      @object = object
    end

    def to_h
      self.class.parameters.map do |parameter_name, _|
        if object.has_key?(parameter_name)
          [parameter_name, object[parameter_name]]
        end
      end.to_h
    end
  end
end
