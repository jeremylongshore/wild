# frozen_string_literal: true

module Wild
  module Analyzers
    module Permission
      module Analyzers
        class RiskAnalyzer
          def initialize(config = Wild.config.analyzers.permission)
            @config = config
          end

          def analyze(capabilities, grants)
            cap_index = capabilities.index_by { |c| c.name } # rubocop:disable Style/SymbolProc
            threshold_rank = @config.risk_levels[@config.wildcard_risk_threshold] || 2

            grants.flat_map do |grant|
              wildcard_findings(grant, cap_index, threshold_rank) +
                no_expiry_findings(grant, cap_index)
            end
          end

          private

          def wildcard_findings(grant, cap_index, threshold_rank)
            grant.wildcard_capabilities.flat_map do |pattern|
              risky_caps(pattern, cap_index, threshold_rank).map do |cap|
                wildcard_finding(grant, pattern, cap)
              end
            end
          end

          def risky_caps(pattern, cap_index, threshold_rank)
            cap_index.values.select do |cap|
              WildcardMatcher.matches?(pattern, cap.name) &&
                (@config.risk_levels[cap.risk_level] || 0) >= threshold_rank
            end
          end

          def wildcard_finding(grant, pattern, cap)
            Models::Finding.new(
              type: :wildcard_on_critical,
              severity: risk_severity(cap.risk_level),
              message: "Wildcard pattern '#{pattern}' granted to '#{grant.caller_id}' " \
                       "covers #{cap.risk_level}-risk capability '#{cap.name}'",
              evidence: { caller_id: grant.caller_id, pattern: pattern, capability: cap.name,
                          risk_level: cap.risk_level }
            )
          end

          def no_expiry_findings(grant, cap_index)
            elevated = elevated_caps(grant, cap_index)
            return [] if elevated.empty? || !grant.expires_at.nil?

            [Models::Finding.new(
              type: :no_expiry_elevated,
              severity: :warning,
              message: "Grant for '#{grant.caller_id}' has no expiry but covers elevated capabilities: " \
                       "#{elevated.first(3).inspect}",
              evidence: { caller_id: grant.caller_id, elevated_capabilities: elevated }
            )]
          end

          def elevated_caps(grant, cap_index)
            grant.capabilities.select do |pattern|
              resolve_pattern_caps(pattern, cap_index).any? { |cap| (@config.risk_levels[cap.risk_level] || 0) >= 2 }
            end
          end

          def resolve_pattern_caps(pattern, cap_index)
            if pattern.include?("*")
              cap_index.values.select { |c| WildcardMatcher.matches?(pattern, c.name) }
            else
              [cap_index[pattern]].compact
            end
          end

          def risk_severity(risk_level)
            case risk_level
            when "critical" then :critical
            when "high" then :error
            else :warning
            end
          end
        end
      end
    end
  end
end
