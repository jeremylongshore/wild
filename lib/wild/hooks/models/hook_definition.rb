# frozen_string_literal: true

module Wild::Hooks
  module Models
    # Describes a named hook point in the system.
    #
    # A HookDefinition declares what trigger it corresponds to, what permissions
    # are required to register handlers against it, and whether it has been
    # deprecated.
    class HookDefinition
      KNOWN_TRIGGERS = %i[
        before_tool_call
        after_tool_call
        before_session
        after_session
        on_error
        on_capability_check
      ].freeze

      attr_reader :name,
                  :trigger,
                  :description,
                  :required_permissions,
                  :version,
                  :deprecated,
                  :registered_at

      alias deprecated? deprecated

      def initialize(name:, trigger:, description: '', required_permissions: [], version: '1.0.0',
                     deprecated: false)
        @name                 = validate_name!(name)
        @trigger              = validate_trigger!(trigger)
        @description          = String(description)
        @required_permissions = Array(required_permissions).map(&:to_s).freeze
        @version              = String(version)
        @deprecated           = deprecated == true
        @registered_at        = Time.now
      end

      def ==(other)
        other.is_a?(HookDefinition) && name == other.name
      end

      def to_h
        {
          name: name,
          trigger: trigger,
          description: description,
          required_permissions: required_permissions,
          version: version,
          deprecated: deprecated,
          registered_at: registered_at
        }
      end

      def inspect
        "#<Wild::Hooks::Models::HookDefinition name=#{name.inspect} trigger=#{trigger.inspect} " \
          "version=#{version.inspect} deprecated=#{deprecated.inspect}>"
      end

      private

      def validate_name!(name)
        raise ArgumentError, 'name must be a non-empty String' \
          unless name.is_a?(String) && !name.strip.empty?

        name
      end

      def validate_trigger!(trigger)
        raise ArgumentError, "trigger must be a Symbol, got #{trigger.inspect}" \
          unless trigger.is_a?(Symbol)

        trigger
      end
    end
  end
end
