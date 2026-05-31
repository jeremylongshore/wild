# frozen_string_literal: true

module Wild
  module Analyzers
    module Permission
      module Analyzers
        module WildcardMatcher
          # Returns true if pattern matches capability_name.
          # Supports trailing "*" as well as mid-string "*".
          # Examples:
          #   matches?("admin.jobs.*", "admin.jobs.retry")  => true
          #   matches?("admin.jobs.view", "admin.jobs.view") => true
          #   matches?("admin.*", "admin.jobs.retry")        => true
          def self.matches?(pattern, capability_name)
            return capability_name == pattern unless pattern.include?("*")

            regex_str = Regexp.escape(pattern).gsub('\\*', ".*")
            Regexp.new("\\A#{regex_str}\\z").match?(capability_name)
          end

          # Given a list of grant capability patterns, return all capability names
          # from the capability set that are covered.
          def self.resolve_patterns(patterns, capability_names)
            capability_names.select do |cap_name|
              patterns.any? { |pattern| matches?(pattern, cap_name) }
            end
          end
        end
      end
    end
  end
end
