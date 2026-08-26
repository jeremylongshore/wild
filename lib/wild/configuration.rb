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
  #     config.introspection.blocked_resources_path =
  #       Rails.root.join("config/wild/blocked_resources.yml")
  #
  #     # cache_adapter / job_adapter / flag_adapter default to :default (see
  #     # Wild::Configuration::AdminTools below); Wild::Engine's after_initialize
  #     # hook resolves :default to a concrete Wild::AdminTools::Executor::
  #     # Adapters instance wrapping Rails.cache / Sidekiq / Flipper when that
  #     # backend gem is loaded, or raises Wild::ConfigurationError naming the
  #     # unresolvable setting. Only Sidekiq is a shipped job_adapter backend
  #     # today (there is no ActiveJob::Base-wrapping adapter: ActiveJob has no
  #     # generic queue-introspection API); apps on a different queue backend, or
  #     # apps that want a job_adapter/flag_adapter without Sidekiq/Flipper
  #     # installed, must set one explicitly here.
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
  # rubocop:disable Metrics/ClassLength -- data aggregator: holds every namespace's nested settings Struct, so its length grows with the namespace count by design, not with logic complexity
  class Configuration
    # Settings classes for each namespace.
    #
    # Convention:
    #   - Single-leaf namespaces are `Struct.new(..., keyword_init: true)`.
    #     They default all settings to `nil` unless an `initialize` override
    #     sets a council-blessed default (F2 hard_fail, F5 false, etc.).
    #   - Multi-leaf namespaces (Telemetry, Analyzers) are plain Ruby classes
    #     wrapping their leaf Structs via `attr_reader`. The wrapper class
    #     instantiates each leaf with its own defaults.
    #
    # Mutation is expected during `Wild.configure { ... }` and read-only
    # thereafter. The engine does not freeze the config (by design — so test
    # code can override per example) but production code does not mutate
    # post-boot.

    # `allowed_models: nil` means "derive from access_policy_path"; the
    # introspection runtime treats nil and empty-array distinctly.
    # `blocked_resources_path` is required by Wild::Introspection::Configuration
    # #load! alongside access_policy_path (f-l09-2): both are bridged into the
    # runtime policy loader at Wild::Engine after_initialize.
    Introspection = Struct.new(
      :access_policy_path,
      :blocked_resources_path,
      :allowed_models,
      keyword_init: true
    )

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
      :validate_audit_events,
      keyword_init: true
    ) do
      def initialize(**kwargs)
        super(
          capabilities_path: kwargs.fetch(:capabilities_path, nil),
          # CURRENTLY INERT (Armstrong F2 gate, wild-28y): Evaluator#evaluate
          # unconditionally fails closed (deny + audit, never raises) and does
          # NOT read this knob. The :hard_fail default documents intent but does
          # nothing yet — setting it does NOT produce raise semantics. Wiring an
          # opt-in raising mode (emit-then-raise Wild::CapabilityGate::
          # EvaluationError) or cutting the knob is decide-or-cut under wild-28y.
          # Do not infer raise-on-eval-error behaviour from this default.
          on_evaluation_error: kwargs.fetch(:on_evaluation_error, :hard_fail),
          # F2 (wild-rvv.4.1.2): validate every emitted audit event against
          # audit_event.yml. `:auto` (default) → on in dev/test, off in prod
          # (validation cost is real; a non-conforming event is a developer bug
          # we want surfaced in dev/test, not in production). `true`/`false`
          # force the behaviour regardless of environment.
          validate_audit_events: kwargs.fetch(:validate_audit_events, :auto)
        )
      end
    end

    # Telemetry has three sub-namespaces; group them under a parent.
    class Telemetry
      # Collector carries the session-telemetry knobs the old gem exposed
      # (store, retention_days, privacy_mode, max_storage_bytes) plus the
      # PR-B `enabled` flag. Defaults preserved verbatim; the gem's per-setter
      # validation + freeze! machinery is NOT carried over (no-freeze design).
      Collector = Struct.new(
        :enabled,
        :store,
        :retention_days,
        :privacy_mode,
        :max_storage_bytes,
        keyword_init: true
      ) do
        def initialize(**kwargs)
          super(
            enabled: kwargs.fetch(:enabled, true),
            store: kwargs.fetch(:store, nil),
            retention_days: kwargs.fetch(:retention_days, 90),
            privacy_mode: kwargs.fetch(:privacy_mode, :strict),
            max_storage_bytes: kwargs.fetch(:max_storage_bytes, nil)
          )
        end
      end

      # Pipeline carries the transcript-pipeline knobs the old gem exposed
      # plus the PR-B `sequence_strategy` flag. Defaults preserved verbatim;
      # the gem's per-setter validation + freeze! machinery is NOT carried
      # over (no-freeze design).
      Pipeline = Struct.new(
        :sequence_strategy,
        :intent_confidence_threshold,
        :max_turn_content_length,
        :max_turns_per_transcript,
        :redaction_marker,
        :strip_absolute_paths,
        :strip_file_contents,
        :custom_patterns,
        keyword_init: true
      ) do
        def initialize(**kwargs)
          super(
            sequence_strategy: kwargs.fetch(:sequence_strategy, :ingest_order),
            intent_confidence_threshold: kwargs.fetch(:intent_confidence_threshold, 0.5),
            max_turn_content_length: kwargs.fetch(:max_turn_content_length, 10_000),
            max_turns_per_transcript: kwargs.fetch(:max_turns_per_transcript, 1_000),
            redaction_marker: kwargs.fetch(:redaction_marker, "[REDACTED]"),
            strip_absolute_paths: kwargs.fetch(:strip_absolute_paths, true),
            strip_file_contents: kwargs.fetch(:strip_file_contents, true),
            custom_patterns: kwargs.fetch(:custom_patterns, [])
          )
        end
      end

      ANALYSIS_DEFAULT_SEVERITY_WEIGHTS = {
        denial: 1.0, failure: 1.0, latency: 1.0,
        utilization: 1.0, coverage: 1.0, pattern: 1.0
      }.freeze

      # Analysis carries the gap-miner thresholds the old gem exposed plus the
      # PR-B `gap_threshold` flag (placeholder — not read by the moved code;
      # kept for back-compat). Defaults preserved verbatim from the gem's
      # DEFAULTS hash; per-setter validation + freeze! machinery NOT carried
      # over (no-freeze design).
      Analysis = Struct.new(
        :gap_threshold,
        :denial_threshold,
        :failure_threshold,
        :latency_p95_threshold_ms,
        :utilization_min_count,
        :coverage_min_fraction,
        :pattern_min_occurrences,
        :max_gaps_per_type,
        :severity_weights,
        keyword_init: true
      ) do
        def initialize(**kwargs)
          super(
            gap_threshold: kwargs.fetch(:gap_threshold, 0.7),
            denial_threshold: kwargs.fetch(:denial_threshold, 0.2),
            failure_threshold: kwargs.fetch(:failure_threshold, 0.15),
            latency_p95_threshold_ms: kwargs.fetch(:latency_p95_threshold_ms, 500.0),
            utilization_min_count: kwargs.fetch(:utilization_min_count, 5),
            coverage_min_fraction: kwargs.fetch(:coverage_min_fraction, 0.3),
            pattern_min_occurrences: kwargs.fetch(:pattern_min_occurrences, 3),
            max_gaps_per_type: kwargs.fetch(:max_gaps_per_type, 50),
            severity_weights: kwargs.fetch(:severity_weights, ANALYSIS_DEFAULT_SEVERITY_WEIGHTS.dup)
          )
        end
      end

      attr_reader :collector, :pipeline, :analysis

      def initialize
        @collector = Collector.new
        @pipeline = Pipeline.new
        @analysis = Analysis.new
      end
    end

    # Hooks consolidates the seven knobs the old wild-hook-ops gem exposed
    # plus the engine-shape `lifecycle` flag. Defaults preserve old-gem
    # behavior verbatim so the Role 5 move is structure, not behavior.
    # (Validation that the old setters performed at write time is dropped
    # here — flagged for follow-up under wild-rvv.6 children.)
    Hooks = Struct.new(
      :default_timeout_ms,
      :max_handlers_per_hook,
      :enable_audit_logging,
      :max_audit_entries,
      :execution_mode,
      :on_handler_error,
      :lifecycle,
      keyword_init: true
    ) do
      def initialize(**kwargs)
        super(
          default_timeout_ms: kwargs.fetch(:default_timeout_ms, 5_000),
          max_handlers_per_hook: kwargs.fetch(:max_handlers_per_hook, 20),
          enable_audit_logging: kwargs.fetch(:enable_audit_logging, true),
          max_audit_entries: kwargs.fetch(:max_audit_entries, 10_000),
          execution_mode: kwargs.fetch(:execution_mode, :sequential),
          on_handler_error: kwargs.fetch(:on_handler_error, :log_and_continue),
          # :rails_engine when mounted in Rails; :standalone for bin-script consumers
          lifecycle: kwargs.fetch(:lifecycle, :rails_engine)
        )
      end
    end

    # Analyzers has two sub-namespaces; group them under a parent.
    class Analyzers
      PERMISSION_DEFAULT_RISK_LEVELS = {
        "low" => 1, "medium" => 2, "high" => 3, "critical" => 4
      }.freeze

      # Permission carries the audit-policy knobs the old wild-permission-analyzer
      # gem exposed plus the `cycle_detection` flag from PR-B (consumed by the
      # Fowler detect_cycle fix — wild-rvv.7 follow-up). Defaults preserved verbatim
      # from the old gem; the gem's per-setter validation + freeze! machinery is
      # NOT carried over (Wild's no-freeze configuration design).
      #
      # `max_prerequisite_depth` was REMOVED (wild-0e0): the Role 6 detect_cycle
      # rework (Fowler findings 1+10, PR-2) replaced the depth-limited cycle check
      # with tri-color DFS, leaving the knob wired to nothing. Dead config erodes
      # trust in live config, so it was cut rather than left inert. A future
      # "warn beyond operational depth" finding, if ever wanted, is a clean
      # additive feature (new knob + :warning finding) under its own bead — not a
      # reserved hook carried speculatively.
      Permission = Struct.new(
        :cycle_detection,
        :capabilities_path,
        :grants_path,
        :risk_levels,
        :wildcard_risk_threshold,
        keyword_init: true
      ) do
        def initialize(**kwargs)
          super(
            cycle_detection: kwargs.fetch(:cycle_detection, :strict),
            capabilities_path: kwargs.fetch(:capabilities_path, nil),
            grants_path: kwargs.fetch(:grants_path, nil),
            risk_levels: kwargs.fetch(:risk_levels, PERMISSION_DEFAULT_RISK_LEVELS.dup),
            wildcard_risk_threshold: kwargs.fetch(:wildcard_risk_threshold, "medium")
          )
        end
      end

      TEST_FLAKES_DEFAULT_SEVERITY_WEIGHTS = {
        flake_rate: 1.0, failure_count: 1.0, trend: 1.0, confidence: 1.0
      }.freeze

      # TestFlakes carries the flake-detection knobs the old
      # wild-test-flake-forensics gem exposed plus the `classifier_corpus_path`
      # placeholder from PR-B (consumed by the F3 golden-corpus work). Defaults
      # preserved verbatim; the gem's per-setter validation + freeze! machinery
      # is NOT carried over (Wild's no-freeze configuration design).
      #
      # `classifier_corpus_path: nil` means "engineer must supply"; runtime
      # raises Wild::Analyzers::Error if the classifier is invoked without a path.
      TestFlakes = Struct.new(
        :classifier_corpus_path,
        :minimum_runs,
        :flake_rate_threshold,
        :max_history_entries,
        :severity_weights,
        keyword_init: true
      ) do
        def initialize(**kwargs)
          super(
            classifier_corpus_path: kwargs.fetch(:classifier_corpus_path, nil),
            minimum_runs: kwargs.fetch(:minimum_runs, 3),
            flake_rate_threshold: kwargs.fetch(:flake_rate_threshold, 0.1),
            max_history_entries: kwargs.fetch(:max_history_entries, 10_000),
            severity_weights: kwargs.fetch(:severity_weights, TEST_FLAKES_DEFAULT_SEVERITY_WEIGHTS.dup)
          )
        end
      end

      attr_reader :permission, :test_flakes

      def initialize
        @permission = Permission.new
        @test_flakes = TestFlakes.new
      end
    end

    # Skillops carries the registry-policy knobs the old wild-skillops-registry
    # gem exposed (max_skills, max_versions_per_skill, etc.) plus the F5-mandated
    # `enabled` flag. Defaults preserved verbatim from the old gem; the gem's
    # per-setter type validation + freeze!/frozen? machinery is NOT carried
    # over (consistent with Wild's no-freeze configuration design).
    SKILLOPS_DEFAULT_LIFECYCLE_STATES = %i[draft active deprecated retired].freeze
    SKILLOPS_DEFAULT_HEALTH_STATES    = %i[available degraded unavailable unknown].freeze

    Skillops = Struct.new(
      :enabled,
      :max_skills,
      :max_versions_per_skill,
      :health_stale_threshold_hours,
      :allowed_lifecycle_states,
      :allowed_health_states,
      keyword_init: true
    ) do
      def initialize(**kwargs)
        super(
          # F5 — Wild::Skillops is an internal namespace by default.
          # Enable only when a real consumer appears (ADR-0002 path).
          enabled: kwargs.fetch(:enabled, false),
          max_skills: kwargs.fetch(:max_skills, 1_000),
          max_versions_per_skill: kwargs.fetch(:max_versions_per_skill, 50),
          health_stale_threshold_hours: kwargs.fetch(:health_stale_threshold_hours, 24),
          allowed_lifecycle_states: kwargs.fetch(:allowed_lifecycle_states, SKILLOPS_DEFAULT_LIFECYCLE_STATES.dup),
          allowed_health_states: kwargs.fetch(:allowed_health_states, SKILLOPS_DEFAULT_HEALTH_STATES.dup)
        )
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
  # rubocop:enable Metrics/ClassLength
end
