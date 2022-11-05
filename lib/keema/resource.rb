require 'time'
require_relative 'field'
require_relative 'json_schema'
require_relative 'resource/field_selector'
require_relative 'type'
require_relative 'parameters'

module Keema
  class Resource
    VERSION = "0.1.0"

    Bool = ::Keema::Type::Bool

    class RuntimeError < StandardError; end

    class <<self
      # Define a field of json representation
      # @param name [Symbol] Field name
      # @param name [Class] Field type such as Integer, String etc.
      # @param null [Boolean] Whether the field value can be null. Default is not null.
      # @param optional [Boolean] Whether the field can be not defined. Default is not optional, which means required.
      # @example
      #   field :id, Integer
      #   field :name, String
      #   field :address, String, null: true
      def field(name, type, null: false, optional: false, default: nil, **options)
        @fields ||= {}
        field = ::Keema::Field.new(name: name, type: type, null: null, optional: optional, default: default)
        @fields[field.name] = field
      end

      def enum(*values)
        ::Keema::Type::Enum.new(values)
      end

      def fields
        @fields ||= {}
      end

      def select(selector)
        new(schema_fields: selector, required_schema_fields: selector)
      end

      def is_keema_resource_class?
        true
      end

      # Return openapi-compatible json schema
      # @return [Hash] json schema
      def to_openapi
        to_json_schema(openapi: true)
      end

      # Return JSON Schema
      # @param openapi [Boolean] If true, return OpenAPI schema
      # @return [Hash] The JSON Schema
      def to_json_schema(openapi: false)
        new.to_json_schema(openapi: openapi)
      end

      # Return json serializable hash
      # @param object [Object] object
      # @param context [Hash] context can be accessed from serializers in this serialization
      # @return [Hash] The json representation of the object
      # @example
      #   UserResource.serialize(user)
      #   # => { id: 1, name: 'John' }
      def serialize(object, context: {})
        new(context: context).serialize(object)
      end
    end

    attr_reader :object, :context, :selected_fields
    def initialize(schema_fields: nil, required_schema_fields: [:*], context: {}, fields: [:*])
      @context = context
      @selected_fields = fields
      @schema_fields_selector = schema_fields || self.class.fields.keys
      @required_schema_fields_selector = required_schema_fields
    end


    def serialization_fields
      schema_fields.select { |field|
        field_selector.field_names.include?(field)
      }
    end

    def is_keema_resource_class?
      true
    end

    def to_json_schema(openapi: false)
      {
        title: json_schema_title,
        type: :object,
        properties: schema_fields.map do |name, field|
          [
            name, field.to_json_schema(openapi: openapi),
          ]
        end.to_h,
        additionalProperties: false,
        required: required_schema_fields.values.map(&:name),
      }
    end


    def serialize(object)
      is_hash_like = object.respond_to?(:keys) || object.is_a?(Struct)
      if !is_hash_like && object.respond_to?(:each)
        object.map do |item|
          serialize_one(item)
        end
      else
        serialize_one(object)
      end
    end

    def json_schema_title
      self.class.name&.gsub('::', '') || ''
    end

    private

    def serialize_one(object)
      @object = object
      hash = {}
      serialization_fields.each do |field_name, field|
        value =
          if respond_to?(field_name)
            send(field_name)
          elsif object.respond_to?(field_name)
            object.public_send(field_name)
          elsif object.respond_to?(:"#{field_name}?")
            object.public_send(:"#{field_name}?")
          else
            raise ::Keema::Resource::RuntimeError.new("object #{object.inspect} does not respond to `#{field_name}` (#{self.class.name})")
          end

        type = field.type

        is_array = type.is_a?(Array)
        sub_type = is_array ? type.first : type
        values = is_array ? value : [value]

        result = values.map do |value|
          case
          when sub_type == Time
            value.iso8601(3)
          when value && sub_type.respond_to?(:is_keema_resource_class?) && sub_type.is_keema_resource_class?
            sub_type.new(
              schema_fields: schema_field_selector.fetch(field_name),
              required_schema_fields: required_schema_field_selector.fetch(field_name),
              fields: field_selector.fetch(field_name),
              context: context,
            ).serialize(value)
          else
            value
          end
        end

        hash[field_name] = (is_array ? result : result.first)
        if field.default
          hash[field_name] ||= field.default
        end
      end

      @object = nil

      hash
    end

    attr_reader :schema_fields_selector, :required_schema_fields_selector

    def field_selector
      @field_selector ||= FieldSelector.new(resource: self.class, selector: selected_fields)
    end

    def schema_field_selector
      ::Keema::Resource::FieldSelector.new(selector: schema_fields_selector, resource: self.class)
    end

    def schema_fields
      self.class.fields.select { |name| schema_field_selector.field_names.include?(name) }
    end

    def required_schema_field_selector
      ::Keema::Resource::FieldSelector.new(selector: required_schema_fields_selector, resource: self.class)
    end

    def required_schema_fields
      self.class.fields.select { |name| required_schema_field_selector.field_names.include?(name) }
    end
  end
end
