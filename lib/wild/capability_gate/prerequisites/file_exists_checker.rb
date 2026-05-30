# frozen_string_literal: true

module Wild
  module CapabilityGate
    module Prerequisites
      # Checks that a file exists at the path specified in the prerequisite.
      #
      # Prerequisite params:
      #   path: (String) file path to check — absolute or relative to cwd
      #
      # Fail-closed: if the check itself errors, returns failure.
      class FileExistsChecker
        def self.check(prerequisite, context: {}) # rubocop:disable Lint/UnusedMethodArgument
          path = prerequisite.params[:path]
          return missing_path_result if path.nil? || path.to_s.empty?

          File.exist?(path) ? CheckResult.passed : CheckResult.failed(details: "required file not found: #{path}")
        rescue StandardError => e
          CheckResult.failed(details: "file_exists check failed: #{e.class}")
        end

        def self.missing_path_result
          CheckResult.failed(details: "file_exists prerequisite missing required path parameter")
        end
        private_class_method :missing_path_result
      end
    end
  end
end
