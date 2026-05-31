# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Ingestion
        class ExportParser
          attr_reader :config

          def initialize(config: Wild.config.telemetry.analysis)
            @config = config
          end

          # Parses a JSONL export file.
          # Returns a hash:
          #   { header: ExportHeader, records: Hash<Symbol, Array<TelemetryRecord>> }
          def parse_file(path)
            raise ParseError, "file not found: #{path}" unless File.exist?(path)

            lines = File.readlines(path, chomp: true).reject(&:empty?)
            raise ParseError, "export file is empty" if lines.empty?

            parse_lines(lines)
          end

          # Parses a string of JSONL content (useful for testing).
          def parse_string(content)
            lines = content.split("\n").map(&:strip).reject(&:empty?)
            raise ParseError, "export content is empty" if lines.empty?

            parse_lines(lines)
          end

          private

          def parse_lines(lines)
            header_data = parse_json(lines.first, line_number: 1)
            header = build_header(header_data)

            records = build_records(lines.drop(1))

            { header: header, records: records }
          end

          def parse_json(line, line_number:)
            JSON.parse(line)
          rescue JSON::ParserError => e
            raise ParseError, "invalid JSON on line #{line_number}: #{e.message}"
          end

          def build_header(data)
            header = Models::ExportHeader.new(data)
            unless header.valid?
              raise SchemaError, "export header missing required fields (export_type, schema_version, source_id)"
            end

            header
          end

          def build_records(lines)
            records = Hash.new { |h, k| h[k] = [] }

            lines.each_with_index do |line, index|
              data = parse_json(line, line_number: index + 2)
              record = RecordFactory.build(data)
              records[record.record_type.to_sym] << record
            end

            records
          end
        end
      end
    end
  end
end
