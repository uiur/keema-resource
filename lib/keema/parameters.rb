require_relative 'resource'

module Keema
  class Parameters
    class Parameter
      attr_reader :field
      def initialize(field:, in:, options: {})
        @field = field
        @location_in = binding.local_variable_get(:in)
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

      def in_body?
        location_in == :body
      end

      def required?
        if location_in == :path
          # If the parameter location is "path", this property is REQUIRED and its value MUST be true.
          true
        else
          !field.optional
        end
      end

      private
      attr_reader :location_in, :options
    end

    class <<self
      attr_reader :parameters, :resource_class
      def field(name, type, in: :query, null: false, optional: false, default: nil, **options)
        @parameters ||= {}
        @resource_class ||= Class.new(::Keema::Resource)
        field = ::Keema::Field.new(
          name: name,
          type: type,
          null: null,
          optional: optional,
          default: default,
          **options,
        )

        location_in = binding.local_variable_get(:in)
        if location_in == :body
          resource_class.fields[field.name] = field
        else
          parameter = ::Keema::Parameters::Parameter.new(
            field: field,
            in: location_in,
            options: options
          )
          @parameters[parameter.name] = parameter
        end
        define_parameter_getter(field)
      end

      def enum(*values)
        ::Keema::Type::Enum.new(values)
      end

      def to_openapi
        {
          parameters: parameters.values.map(&:to_openapi),
          requestBody: {
            content: {
              'application/json' => {
                schema: resource_class.to_openapi
              }
            }
          }
        }
      end

      private

      def define_parameter_getter(field)
        define_method(field.name) do
          object[field.name] || field.default
        end
      end
    end

    # object is a hash-like object
    attr_reader :object
    def initialize(object)
      @object = object
    end

    def to_h
      (self.class.parameters.transform_values(&:field).to_a + self.class.resource_class.fields.to_a).map do |field_name, _|
        if object.has_key?(field_name)
          [field_name, public_send(field_name)]
        end
      end.compact.to_h
    end
  end
end
