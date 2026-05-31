# frozen_string_literal: true

module Wild
  module Analyzers
    module TestFlakes
      module Models
        class TestIdentity
          attr_reader :file_path, :test_name, :context

          def initialize(file_path:, test_name:, context: nil)
            raise ArgumentError, "file_path cannot be nil or empty" if file_path.to_s.strip.empty?
            raise ArgumentError, "test_name cannot be nil or empty" if test_name.to_s.strip.empty?

            @file_path = file_path.to_s.freeze
            @test_name = test_name.to_s.freeze
            @context = context.to_s.freeze
          end

          def key
            "#{file_path}::#{context}::#{test_name}".freeze
          end

          def ==(other)
            other.is_a?(TestIdentity) && key == other.key
          end

          alias eql? ==

          delegate :hash, to: :key

          def to_h
            { file_path: file_path, test_name: test_name, context: context }
          end

          def to_s
            context.empty? ? "#{file_path} — #{test_name}" : "#{file_path} — #{context} — #{test_name}"
          end
        end
      end
    end
  end
end
