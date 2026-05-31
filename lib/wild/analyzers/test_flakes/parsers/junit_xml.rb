# frozen_string_literal: true

require "rexml/document"
require "time"

module Wild
  module Analyzers
    module TestFlakes
      module Parsers
        class JunitXml < Base
          def parse(input, run_id: nil, timestamp: nil)
            require_non_empty!(input)

            doc = parse_xml!(input)
            extract_test_cases(doc, coerce_run_id(run_id), timestamp || default_timestamp)
          end

          private

          def parse_xml!(input)
            doc = REXML::Document.new(input)
            root = doc.root
            raise ParseError, "JUnit XML must have a root element" if root.nil?

            unless %w[testsuite testsuites].include?(root.name)
              raise ParseError, "JUnit XML root must be <testsuite> or <testsuites>, got: <#{root.name}>"
            end

            doc
          rescue REXML::ParseException => e
            raise ParseError, "Invalid XML: #{e.message}"
          end

          def extract_test_cases(doc, run_id, timestamp)
            results = []
            REXML::XPath.each(doc, "//testcase") do |node|
              result = build_result_from_node(node, run_id, timestamp)
              results << result if result
            end
            results
          end

          def build_result_from_node(node, run_id, timestamp)
            identity = extract_node_identity(node)
            status, error_message = determine_status(node)
            build_result(
              identity: identity,
              status: status,
              run_id: run_id,
              timestamp: timestamp,
              duration_ms: parse_duration(node),
              error_message: error_message
            )
          rescue ArgumentError
            nil
          end

          def extract_node_identity(node)
            classname = node.attributes["classname"] || ""
            test_name = node.attributes["name"] || "unknown"
            build_identity(
              file_path: classname.empty? ? "unknown" : classname_to_file(classname),
              test_name: test_name,
              context: classname
            )
          end

          def parse_duration(node)
            time_attr = node.attributes["time"]
            time_attr ? (time_attr.to_f * 1000).round(3) : nil
          end

          # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
          def determine_status(node)
            failure = REXML::XPath.first(node, "failure")
            error_el = REXML::XPath.first(node, "error")
            skipped = REXML::XPath.first(node, "skipped")

            if failure
              [:failed, failure.attributes["message"] || failure.text&.strip]
            elsif error_el
              [:errored, error_el.attributes["message"] || error_el.text&.strip]
            elsif skipped
              [:skipped, nil]
            else
              [:passed, nil]
            end
          end
          # rubocop:enable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity

          def classname_to_file(classname)
            "#{classname.gsub("::", "/").gsub(".", "/")}.rb"
          end
        end
      end
    end
  end
end
