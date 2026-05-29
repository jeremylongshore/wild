# frozen_string_literal: true

module Wild
  # The single Configuration block for the gem (F1 fix — closes the nine
  # broken Configuration singletons in the old wild-* gems).
  #
  # Typed nested accessors per `000-docs/003-AT-ARCH-architecture.md`
  # § "Configuration shape". Each namespace has a declared settings class
  # under `Wild::Configuration::<Namespace>` with documented attributes and
  # sensible defaults. Mutation through `Wild.configure { |c| ... }`.
  #
  # Example (lifted verbatim from the architecture doc):
  #
  #   Wild.configure do |config|
  #     config.audit_logger = Rails.logger
  #     config.environment  = Rails.env.to_sym
  #
  #     config.introspection.access_policy_path =
  #       Rails.root.join("config/wild/access_policy.yml")
  #
  #     config.admin_tools.cache_adapter = Rails.cache         # defaulted
  #     config.admin_tools.job_adapter   = ActiveJob::Base     # defaulted
  #     config.admin_tools.flag_adapter  = Flipper             # defaulted
  #                                                              # if Flipper loaded
  #
  #     config.capability_gate.on_evaluation_error = :hard_fail # F2-mandated
  #
  #     config.telemetry.collector.enabled        = true
  #     config.telemetry.pipeline.sequence_strategy = :ingest_order
  #     config.telemetry.analysis.gap_threshold   = 0.7
  #
  #     config.hooks.lifecycle = :rails_engine
  #
  #     config.analyzers.permission.cycle_detection = :strict
  #     config.analyzers.test_flakes.classifier_corpus_path =
  #       Rails.root.join("config/wild/test_flakes_corpus.yml")
  #
  #     config.skillops.enabled = false  # F5 — default off
  #   end
  #
  # Per `ADR-0003`, this configuration substrate sits at "Tier 0" — it's
  # public to every namespace; every namespace reads its own slice. No
  # namespace owns or mutates another namespace's settings at runtime.
  class Configuration
    # Settings classes for each namespace. Each is a small typed Struct
    # with keyword_init defaults. Mutation is expected during
    # `Wild.configure { ... }` and read-only thereafter (the engine does
    # not freeze the config — by design, so test code can override per
    # example — but production code does not mutate post-boot).

    Introspection = Struct.new(
      :access_policy_path,
      :allowed_models,
      keyword_init: true
    ) do
      def initialize(**kwargs)
        super(
          access_policy_path: kwargs.fetch(:access_policy_path, nil),
          allowed_models: kwargs.fetch(:allowed_models, nil) # nil = derive from policy
        )
      end
    end

    AdminTools = Struct.new(
      :cache_adapter,
      :job_adapter,
      :flag_adapter,
      keyword_init: true
    ) do
      # Defaults resolve lazily so requiring `wild` outside a Rails app
      # doesn't crash. Consumers in a Rails app get Rails.cache + ActiveJob
      # + Flipper automatically.
      def initialize(**kwargs)
        super(
          cache_adapter: kwargs.fetch(:cache_adapter, :default),
          job_adapter: kwargs.fetch(:job_adapter, :default),
          flag_adapter: kwargs.fetch(:flag_adapter, :default)
        )
      end
    end

    CapabilityGate = Struct.new(
      :capabilities_path,
      :on_evaluation_error,
      keyword_init: true
    ) do
      def initialize(**kwargs)
        super(
          capabilities_path: kwargs.fetch(:capabilities_path, nil),
          # F2 mandate: :evaluation_error is hard-fail. Default reflects this.
          on_evaluation_error: kwargs.fetch(:on_evaluation_error, :hard_fail)
        )
      end
    end

    # Telemetry has three sub-namespaces; group them under a parent.
    class Telemetry
      Collector = Struct.new(:enabled, keyword_init: true) do
        def initialize(**kwargs)
          super(enabled: kwargs.fetch(:enabled, true))
        end
      end

      Pipeline = Struct.new(:sequence_strategy, keyword_init: true) do
        def initialize(**kwargs)
          super(sequence_strategy: kwargs.fetch(:sequence_strategy, :ingest_order))
        end
      end

      Analysis = Struct.new(:gap_threshold, keyword_init: true) do
        def initialize(**kwargs)
          super(gap_threshold: kwargs.fetch(:gap_threshold, 0.7))
        end
      end

      attr_reader :collector, :pipeline, :analysis

      def initialize
        @collector = Collector.new
        @pipeline = Pipeline.new
        @analysis = Analysis.new
      end
    end

    Hooks = Struct.new(:lifecycle, keyword_init: true) do
      def initialize(**kwargs)
        # :rails_engine when mounted in Rails; :standalone for bin-script consumers
        super(lifecycle: kwargs.fetch(:lifecycle, :rails_engine))
      end
    end

    # Analyzers has two sub-namespaces; group them under a parent.
    class Analyzers
      Permission = Struct.new(:cycle_detection, keyword_init: true) do
        def initialize(**kwargs)
          super(cycle_detection: kwargs.fetch(:cycle_detection, :strict))
        end
      end

      TestFlakes = Struct.new(:classifier_corpus_path, keyword_init: true) do
        def initialize(**kwargs)
          super(classifier_corpus_path: kwargs.fetch(:classifier_corpus_path, nil))
        end
      end

      attr_reader :permission, :test_flakes

      def initialize
        @permission = Permission.new
        @test_flakes = TestFlakes.new
      end
    end

    Skillops = Struct.new(:enabled, keyword_init: true) do
      def initialize(**kwargs)
        # F5 — Wild::Skillops is an internal namespace by default.
        # Enable only when a real consumer appears (ADR-0002 path).
        super(enabled: kwargs.fetch(:enabled, false))
      end
    end

    # The seven top-level namespaces exposed on `Wild.config.<name>`.
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
    attr_reader(*NAMESPACES)

    def initialize
      @audit_logger = nil
      @environment = :development
      @introspection = Introspection.new
      @admin_tools = AdminTools.new
      @capability_gate = CapabilityGate.new
      @telemetry = Telemetry.new
      @hooks = Hooks.new
      @analyzers = Analyzers.new
      @skillops = Skillops.new
    end
  end
end
