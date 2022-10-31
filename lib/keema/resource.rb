require 'time'
require_relative 'field'
require_relative 'json_schema'
require_relative 'resource/field_selector'
require_relative 'type'

module Keema
  class Resource
    VERSION = "0.1.0"

    Bool = ::Keema::Type::Bool

    class RuntimeError < StandardError; end

    class <<self
      def field(name, type, null: false, optional: false, **options)
        @fields ||= {}
        field = ::Keema::Field.new(name: name, type: type, null: null, optional: optional)
        @fields[field.name] = field
      end

      def enum(*values)
        ::Keema::Type::Enum.new(values)
      end

      def fields
        @fields ||= {}
      end

      def select(selector)
        new(fields: selector)
      end

      def is_keema_resource_class?
        true
      end

      def to_json_schema(openapi: false)
        new.to_json_schema(openapi: openapi)
      end

      def serialize(object, context: {})
        new(context: context).serialize(object)
      end
    end

    attr_reader :object, :context, :selected_fields
    def initialize(context: {}, fields: [:*])
      @context = context
      @selected_fields = fields
    end

    def ts_type
      self.class.name&.gsub('::', '')
    end

    def fields
      self.class.fields.select { |field|
        field_selector.field_names.include?(field)
      }
    end

    def is_keema_resource_class?
      true
    end

    def to_json_schema(openapi: false)
      type = self
      {
        title: type.ts_type,
        type: :object,
        properties: type.fields.map do |name, field|
          field_type = field.null ? ::Keema::Type::Nullable.new(field.type) : field.type
          [
            name, ::Keema::JsonSchema.convert_type(
              field_type,
              openapi: openapi
            ),
          ]
        end.to_h,
        additionalProperties: false,
        required: type.fields.values.map(&:name),
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

    private

    def field_selector
      @field_selector ||= FieldSelector.new(resource: self.class, selector: selected_fields)
    end

    def serialize_one(object)
      @object = object
      hash = {}
      fields.each do |field_name, field|
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
            nested_fields = field_selector.fetch(field_name)
            sub_type.new(context: context, fields: nested_fields).serialize(value)
          else
            value
          end
        end

        hash[field_name] = is_array ? result : result.first
      end

      @object = nil

      hash
    end
  end
end
