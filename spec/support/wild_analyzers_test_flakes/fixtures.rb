# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength, Metrics/MethodLength, Metrics/ParameterLists, Metrics/AbcSize

require "time"

module Wild
  module Analyzers
    module TestFlakes
      module TestSupport
        module Fixtures
          BASE_TIMESTAMP = Time.utc(2024, 3, 1, 10, 0, 0)

          module_function

          def rspec_json_string(examples: nil, run_id: "run-001")
            examples ||= default_rspec_examples
            JSON.generate({
                            "version" => "3.13.0",
                            "seed" => 12_345,
                            "summary" => {
                              "run_id" => run_id,
                              "duration" => 2.5,
                              "example_count" => examples.size,
                              "failure_count" => examples.count { |e| e["status"] == "failed" }
                            },
                            "examples" => examples
                          })
          end

          def default_rspec_examples
            [
              {
                "id" => "./spec/models/user_spec.rb[1:1]",
                "description" => "is valid",
                "full_description" => "User is valid",
                "status" => "passed",
                "file_path" => "./spec/models/user_spec.rb",
                "line_number" => 5,
                "run_time" => 0.012
              },
              {
                "id" => "./spec/models/user_spec.rb[1:2]",
                "description" => "validates email",
                "full_description" => "User validates email",
                "status" => "failed",
                "file_path" => "./spec/models/user_spec.rb",
                "line_number" => 10,
                "run_time" => 0.023,
                "exception" => {
                  "class" => "RSpec::Expectations::ExpectationNotMetError",
                  "message" => "expected true but got false"
                }
              },
              {
                "id" => "./spec/services/payment_spec.rb[1:1]",
                "description" => "processes payment",
                "full_description" => "PaymentService processes payment",
                "status" => "passed",
                "file_path" => "./spec/services/payment_spec.rb",
                "line_number" => 8,
                "run_time" => 1.5
              }
            ]
          end

          def junit_xml_string(test_cases: nil)
            cases = test_cases || default_junit_cases
            xml_parts = ['<?xml version="1.0" encoding="UTF-8"?>',
                         '<testsuite name="RSpec" tests="3" failures="1" errors="0" time="2.5">']
            cases.each { |c| xml_parts << c }
            xml_parts << "</testsuite>"
            xml_parts.join("\n")
          end

          def default_junit_cases
            [
              '<testcase classname="User" name="is valid" time="0.012"/>',
              '<testcase classname="User" name="validates email" time="0.023">' \
              '<failure message="expected true but got false">Stack trace here</failure>' \
              "</testcase>",
              '<testcase classname="PaymentService" name="processes payment" time="1.5"/>'
            ]
          end

          def minitest_json_string(tests: nil)
            tests ||= default_minitest_tests
            JSON.generate({ "tests" => tests })
          end

          def default_minitest_tests
            [
              {
                "name" => "test_is_valid",
                "class" => "UserTest",
                "file" => "test/models/user_test.rb",
                "result" => "pass",
                "time" => 0.012
              },
              {
                "name" => "test_validates_email",
                "class" => "UserTest",
                "file" => "test/models/user_test.rb",
                "result" => "fail",
                "time" => 0.023,
                "failure" => 'Expected: true\n  Actual: false'
              },
              {
                "name" => "test_payment_processing",
                "class" => "PaymentServiceTest",
                "file" => "test/services/payment_service_test.rb",
                "result" => "pass",
                "time" => 1.5
              }
            ]
          end

          def make_identity(file_path: "spec/models/user_spec.rb", test_name: "is valid", context: "User")
            Wild::Analyzers::TestFlakes::Models::TestIdentity.new(
              file_path: file_path,
              test_name: test_name,
              context: context
            )
          end

          def make_result(identity: nil, status: :passed, run_id: "run-001",
                          timestamp: nil, duration_ms: 10.0, error_message: nil, metadata: {})
            identity ||= make_identity
            Wild::Analyzers::TestFlakes::Models::TestResult.new(
              test_identity: identity,
              status: status,
              run_id: run_id,
              timestamp: timestamp || BASE_TIMESTAMP,
              duration_ms: duration_ms,
              error_message: error_message,
              metadata: metadata
            )
          end

          def flaky_results(identity: nil, pass_count: 3, fail_count: 2, base_run: "run")
            id = identity || make_identity
            results = []

            pass_count.times do |i|
              results << make_result(
                identity: id,
                status: :passed,
                run_id: "#{base_run}-#{i + 1}",
                timestamp: BASE_TIMESTAMP + (i * 3600),
                duration_ms: 10.0 + (i * 2)
              )
            end

            fail_count.times do |i|
              results << make_result(
                identity: id,
                status: :failed,
                run_id: "#{base_run}-#{pass_count + i + 1}",
                timestamp: BASE_TIMESTAMP + ((pass_count + i) * 3600),
                duration_ms: 25.0 + (i * 5),
                error_message: "Expected: true, got: false"
              )
            end

            results
          end

          def flake_record_with(root_causes: [], flake_rate_numerator: 2, total: 5, identity: nil)
            id = identity || make_identity
            results = []
            (total - flake_rate_numerator).times do |i|
              results << make_result(identity: id, status: :passed, run_id: "run-#{i + 1}",
                                     timestamp: BASE_TIMESTAMP + (i * 3600))
            end
            flake_rate_numerator.times do |i|
              results << make_result(identity: id, status: :failed,
                                     run_id: "run-#{total - flake_rate_numerator + i + 1}",
                                     timestamp: BASE_TIMESTAMP + ((total - flake_rate_numerator + i) * 3600))
            end

            Wild::Analyzers::TestFlakes::Models::FlakeRecord.new(
              test_identity: id,
              results: results,
              root_causes: root_causes
            )
          end

          def results_with_high_variance(identity: nil)
            id = identity || make_identity
            durations = [5.0, 10.0, 15.0, 200.0, 250.0, 8.0, 300.0]
            statuses = %i[passed passed passed failed failed passed failed]

            durations.each_with_index.map do |d, i|
              make_result(
                identity: id,
                status: statuses[i],
                run_id: "run-#{i + 1}",
                timestamp: BASE_TIMESTAMP + (i * 3600),
                duration_ms: d
              )
            end
          end

          def results_with_external_errors(identity: nil)
            id = identity || make_identity
            [
              make_result(identity: id, status: :passed, run_id: "run-1", timestamp: BASE_TIMESTAMP),
              make_result(identity: id, status: :passed, run_id: "run-2",
                          timestamp: BASE_TIMESTAMP + 3600),
              make_result(identity: id, status: :failed, run_id: "run-3",
                          timestamp: BASE_TIMESTAMP + 7200,
                          error_message: "connection refused: database connection timeout"),
              make_result(identity: id, status: :failed, run_id: "run-4",
                          timestamp: BASE_TIMESTAMP + 10_800,
                          error_message: "Net::ReadTimeout: HTTP request timed out"),
              make_result(identity: id, status: :passed, run_id: "run-5",
                          timestamp: BASE_TIMESTAMP + 14_400)
            ]
          end

          def results_with_timezone_errors(identity: nil)
            id = identity || make_identity
            [
              make_result(identity: id, status: :passed, run_id: "run-1", timestamp: BASE_TIMESTAMP),
              make_result(identity: id, status: :passed, run_id: "run-2",
                          timestamp: BASE_TIMESTAMP + 3600),
              make_result(identity: id, status: :failed, run_id: "run-3",
                          timestamp: BASE_TIMESTAMP + 7200,
                          error_message: "ActiveSupport::TimeZone UTC offset mismatch"),
              make_result(identity: id, status: :passed, run_id: "run-4",
                          timestamp: BASE_TIMESTAMP + 10_800)
            ]
          end

          def results_with_seeds(identity: nil)
            id = identity || make_identity
            [
              make_result(identity: id, status: :passed, run_id: "run-1", timestamp: BASE_TIMESTAMP,
                          metadata: { seed: 12_345 }),
              make_result(identity: id, status: :passed, run_id: "run-2",
                          timestamp: BASE_TIMESTAMP + 3600, metadata: { seed: 12_345 }),
              make_result(identity: id, status: :failed, run_id: "run-3",
                          timestamp: BASE_TIMESTAMP + 7200, metadata: { seed: 99_999 }),
              make_result(identity: id, status: :failed, run_id: "run-4",
                          timestamp: BASE_TIMESTAMP + 10_800, metadata: { seed: 99_999 }),
              make_result(identity: id, status: :passed, run_id: "run-5",
                          timestamp: BASE_TIMESTAMP + 14_400, metadata: { seed: 12_345 })
            ]
          end

          def multiple_flake_records(count: 3, base_file: "spec/models")
            count.times.map do |i|
              id = make_identity(
                file_path: "#{base_file}/model_#{i}_spec.rb",
                test_name: "test_behavior_#{i}",
                context: "Model#{i}"
              )
              flake_record_with(identity: id, flake_rate_numerator: 2, total: 5)
            end
          end

          def triage_entry(severity: :high, score: 0.65, record: nil)
            r = record || flake_record_with(
              root_causes: [
                Wild::Analyzers::TestFlakes::Models::RootCause.new(
                  category: :timing_dependent,
                  confidence: 0.75,
                  description: "High variance"
                )
              ]
            )
            Wild::Analyzers::TestFlakes::Models::TriageEntry.new(
              flake_record: r,
              severity: severity,
              severity_score: score,
              remediations: ["Add retry logic", "Mock time"],
              trend: :stable
            )
          end
        end
      end
    end
  end
end

# rubocop:enable Metrics/ModuleLength, Metrics/MethodLength, Metrics/ParameterLists, Metrics/AbcSize
