# frozen_string_literal: true

require "wild/version"
require "wild/error"
require "wild/configuration"
require "wild/engine"
require "wild/hooks"
require "wild/capability_gate"
require "wild/skillops"
require "wild/analyzers/permission"
require "wild/analyzers/test_flakes"
require "wild/telemetry/collector"
require "wild/telemetry/pipeline"
require "wild/telemetry/analysis"
require "wild/introspection"
require "wild/admin_tools"

# wild — Rails engine + generator: ten Wild::* namespaces consolidated into one
# mountable gem. Council-blessed Topology A. See 000-docs/adr/ADR-0001-topology.md
# for the canonical decision.
module Wild
  class << self
    # Yields the singleton Configuration block for in-app configuration.
    #
    #   Wild.configure do |config|
    #     config.introspection.access_policy_path = ...
    #     config.capability_gate.on_evaluation_error = :hard_fail
    #   end
    def configure
      yield(config) if block_given?
      config
    end

    # The singleton Configuration instance.
    def config
      @config ||= Configuration.new
    end

    # Reset the configuration. Test-only.
    # @api private
    def reset_config!
      @config = Configuration.new
    end
  end
end
