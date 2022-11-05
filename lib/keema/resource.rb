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
      def serialize(object, context: {}, fields: [:*])
        new(context: context, fields: fields).serialize(object)
      end
    end

    attr_reader :object, :context, :selected_fields
    def initialize(schema_fields: nil, required_schema_fields: nil, context: {}, fields: nil)
      @context = context
      @selected_fields = fields || [:*]
      @schema_fields_selector = schema_fields || self.class.fields.keys
      @required_schema_fields_selector = required_schema_fields || self.class.fields.values.reject(&:optional).map(&:name)
    end

    def serialization_fields
      schema_fields.select { |field|
        field_selector.field_names.include?(field)
      }
    end

    def is_keema_resource_class?
      true
    end

    def to_openapi
      to_json_schema(openapi: true)
    end


    def to_json_schema(openapi: false)
      json_schema = {
        title: json_schema_title,
        type: :object,
        properties: schema_fields.map do |name, field|
          type = apply_selector_to_type(field: field, type: field.type)
          field_type = field.null ? ::Keema::Type::Nullable.new(type) : type

          [
            name, ::Keema::JsonSchema.convert_type(field_type, openapi: openapi).merge(field.options)
          ]
        end.to_h,
        additionalProperties: false,
      }

      required_field_names = required_schema_fields.values.map(&:name)
      if required_field_names.size > 0
        json_schema[:required] = required_field_names
      end

      json_schema
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
        value = field_value(field_name)

        type = field.type
        is_array = type.is_a?(Array)
        if is_array && !value.is_a?(Array)
          raise Keema::Resource::RuntimeError.new("expected value type Array but got #{value.class}")
        end

        sub_type = is_array ? type.first : type
        values = is_array ? value : [value]

        result =
          if value && sub_type.respond_to?(:is_keema_resource_class?) && sub_type.is_keema_resource_class?
            sub_type.new(
              schema_fields: schema_field_selector.fetch(field_name),
              required_schema_fields: required_schema_field_selector.fetch(field_name),
              fields: field_selector.fetch(field_name),
              context: context,
            ).serialize(values)
          else
            values.map do |value|
              serialize_value(value: value, type: sub_type)
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

    def serialize_value(value:, type:)
      case
      when type == Time
        value.iso8601(3)
      else
        value
      end
    end

    def field_value(field_name)
      if respond_to?(field_name)
        send(field_name)
      elsif object.respond_to?(field_name)
        object.public_send(field_name)
      elsif object.respond_to?(:"#{field_name}?")
        object.public_send(:"#{field_name}?")
      else
        raise ::Keema::Resource::RuntimeError.new("object #{object.inspect} does not respond to `#{field_name}` (#{self.class.name})")
      end
    end

    def schema_fields
      self.class.fields.select { |name| schema_field_selector.field_names.include?(name) }
    end

    def required_schema_fields
      self.class.fields.select { |name| required_schema_field_selector.field_names.include?(name) }
    end

    attr_reader :schema_fields_selector, :required_schema_fields_selector

    def schema_field_selector
      ::Keema::Resource::FieldSelector.new(selector: schema_fields_selector, default_field_names: [])
    end

    def required_schema_field_selector
      ::Keema::Resource::FieldSelector.new(selector: required_schema_fields_selector, default_field_names: [])
    end

    def field_selector
      @field_selector ||= FieldSelector.new(selector: selected_fields, default_field_names: required_schema_fields.values.map(&:name))
    end

    def apply_selector_to_type(field:, type:)
      if type.is_a?(Array)
        [
          apply_selector_to_type(field: field, type: type.first)
        ]
      else
        if type.respond_to?(:is_keema_resource_class?) && type.is_keema_resource_class?
          type.new(
            schema_fields: schema_field_selector.fetch(field.name),
            required_schema_fields: required_schema_field_selector.fetch(field.name),
          )
        else
          type
        end
      end
    end

  end
end
