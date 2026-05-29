# frozen_string_literal: true

module Wild
  # The single Configuration block for the gem. Replaces the nine broken
  # Configuration singletons in the old wild-* gems (F1 fix).
  #
  # Per-namespace nested accessors:
  #
  #   Wild.configure do |config|
  #     config.introspection.access_policy_path = "..."
  #     config.capability_gate.on_evaluation_error = :hard_fail
  #     config.telemetry.collector.enabled = true
  #   end
  #
  # Each namespace's nested block is a plain Struct-like object exposing
  # documented settings. Namespaces are populated lazily so requiring `wild`
  # doesn't materialize sub-namespace state until a setting is read or set.
  #
  # Final shape is owned by Role 4 (backend-architect) in P1. This skeleton
  # exists so `Wild.configure` is callable from day one and the F1 fix can
  # land incrementally as namespaces collapse into the engine.
  class Configuration
    NAMESPACES = %i[
      introspection
      admin_tools
      capability_gate
      telemetry
      hooks
      analyzers
      skillops
    ].freeze

    attr_accessor :audit_logger, :environment

    def initialize
      @audit_logger = nil
      @environment  = :development
      @namespaces   = {}
    end

    NAMESPACES.each do |ns|
      define_method(ns) do
        @namespaces[ns] ||= namespace_struct_for(ns)
      end
    end

    private

    # Each namespace gets a fresh OpenStruct-like container for its settings.
    # Role 4 will replace this with typed, documented nested accessors during
    # P1; this stub keeps `Wild.configure { |c| c.<ns>.<setting> = ... }`
    # working in the meantime without forcing every namespace setting to be
    # declared upfront.
    def namespace_struct_for(_ns)
      Struct.new(:settings).new({}).tap do |s|
        s.define_singleton_method(:method_missing) do |name, *args|
          if name.to_s.end_with?("=")
            settings[name.to_s.chomp("=").to_sym] = args.first
          elsif args.empty?
            settings[name]
          else
            super(name, *args)
          end
        end

        s.define_singleton_method(:respond_to_missing?) do |_name, _include_private = false|
          true
        end
      end
    end
  end
end
