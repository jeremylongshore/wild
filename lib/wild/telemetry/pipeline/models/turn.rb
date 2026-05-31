# frozen_string_literal: true

module Wild
  module Telemetry
    module Pipeline
      module Models
        class Turn
          VALID_ROLES = %i[user assistant system tool].freeze

          attr_reader :role, :content, :timestamp, :metadata

          def initialize(role:, content:, timestamp: nil, metadata: {})
            validate_role!(role)
            raise ArgumentError, "content must be a String" unless content.is_a?(String)
            raise ArgumentError, "metadata must be a Hash" unless metadata.is_a?(Hash)

            @role = role.to_sym
            @content = content.freeze
            @timestamp = timestamp
            @metadata = metadata.freeze
          end

          def to_h
            {
              role: role,
              content: content,
              timestamp: timestamp&.iso8601,
              metadata: metadata
            }
          end

          def tool_turn?
            role == :tool
          end

          def user_turn?
            role == :user
          end

          def assistant_turn?
            role == :assistant
          end

          def system_turn?
            role == :system
          end

          private

          def validate_role!(role)
            sym = role.to_sym
            return if VALID_ROLES.include?(sym)

            raise ArgumentError, "role must be one of #{VALID_ROLES.inspect}, got: #{role.inspect}"
          end
        end
      end
    end
  end
end
