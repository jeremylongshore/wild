# frozen_string_literal: true

module Wild
  module Telemetry
    module Pipeline
      module Ingestion
        class BaseAdapter
          def self.parse(input, source_id: nil)
            new.parse(input, source_id: source_id)
          end

          def parse(_input, source_id: nil)
            raise NotImplementedError, "#{self.class}#parse is not implemented"
          end

          private

          def require_non_empty!(input)
            raise IngestionError, "input cannot be nil or empty" if input.to_s.strip.empty?
          end

          def generate_source_id
            "source-#{Time.now.utc.to_i}"
          end

          def coerce_source_id(source_id)
            (source_id.to_s.strip.empty? ? generate_source_id : source_id).freeze
          end

          def parse_timestamp(value)
            return nil if value.nil? || value.to_s.strip.empty?

            require "time"
            Time.parse(value.to_s).utc
          rescue ArgumentError
            nil
          end

          def build_turn(role:, content:, timestamp: nil, metadata: {})
            Models::Turn.new(
              role: role,
              content: content.to_s,
              timestamp: timestamp,
              metadata: metadata
            )
          end
        end
      end
    end
  end
end
