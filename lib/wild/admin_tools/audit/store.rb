# frozen_string_literal: true

require "json"

module Wild
  module AdminTools
    module Audit
      class Store
        def append(record)
          raise NotImplementedError, "#{self.class}#append must be implemented"
        end

        def recent(limit: 50)
          raise NotImplementedError, "#{self.class}#recent must be implemented"
        end

        def find(id)
          raise NotImplementedError, "#{self.class}#find must be implemented"
        end

        def count
          raise NotImplementedError, "#{self.class}#count must be implemented"
        end
      end

      class MemoryStore < Store
        def initialize
          super
          @records = []
          @mutex = Mutex.new
        end

        def append(record)
          @mutex.synchronize { @records << record }
          record
        end

        def recent(limit: 50)
          @mutex.synchronize { @records.last(limit).reverse }
        end

        def find(id)
          @mutex.synchronize { @records.find { |r| r.id == id } }
        end

        def count
          @mutex.synchronize { @records.size }
        end

        def clear!
          @mutex.synchronize { @records.clear }
        end
      end

      class JsonLinesStore < Store
        def initialize(path:)
          super()
          @path = path
          @mutex = Mutex.new
          ensure_directory!
        end

        def append(record)
          line = JSON.generate(record.to_h)
          @mutex.synchronize do
            File.open(@path, "a") { |f| f.puts(line) }
          end
          record
        end

        def recent(limit: 50)
          @mutex.synchronize do
            return [] unless File.exist?(@path)

            lines = File.readlines(@path).last(limit).reverse
            lines.map { |line| parse_record(line) }.compact
          end
        end

        def find(id)
          @mutex.synchronize do
            return nil unless File.exist?(@path)

            File.foreach(@path) do |line|
              record = parse_record(line)
              return record if record&.id == id
            end
            nil
          end
        end

        def count
          @mutex.synchronize do
            return 0 unless File.exist?(@path)

            File.foreach(@path).count
          end
        end

        private

        def ensure_directory!
          FileUtils.mkdir_p(File.dirname(@path))
        end

        def parse_record(line)
          data = JSON.parse(line.strip, symbolize_names: true)
          Record.new(**data)
        rescue JSON::ParserError, ArgumentError
          nil
        end
      end
    end
  end
end
