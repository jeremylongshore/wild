# frozen_string_literal: true

module Wild
  module Analyzers
    module Permission
      module Models
        class Grant
          attr_reader :caller_id, :capabilities, :context, :expires_at

          def initialize(caller_id:, capabilities:, context: {}, expires_at: nil)
            @caller_id = caller_id
            @capabilities = Array(capabilities).freeze
            @context = (context || {}).freeze
            @expires_at = expires_at
          end

          def wildcard_capabilities
            capabilities.select { |c| c.include?("*") }
          end

          def expired?
            return false if expires_at.nil?

            Date.parse(expires_at.to_s) < Date.today # rubocop:disable Rails/Date
          rescue ArgumentError, TypeError
            false
          end

          def ==(other)
            other.is_a?(Grant) && caller_id == other.caller_id && capabilities == other.capabilities
          end

          alias eql? ==

          def hash
            [caller_id, capabilities].hash
          end
        end
      end
    end
  end
end
