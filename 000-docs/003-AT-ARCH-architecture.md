# Architecture: wild

> Engine shape, namespace layout, boundary discipline.

**Author:** Jeremy Longshore
**Date:** 2026-05-28
**Status:** Draft (P1 engine architecture deliverable)

## Top-level shape

`wild` is one Rails engine gem. The entry point is `lib/wild.rb` which:

1. Loads `lib/wild/version.rb` (the one and only version constant)
2. Loads `lib/wild/error.rb` (the `Wild::Error` base hierarchy)
3. Loads `lib/wild/configuration.rb` (the one `Wild::Configuration` with nested accessors)
4. Loads `lib/wild/engine.rb` (the `Wild::Engine` Rails engine)
5. Autoloads ten namespace directories under `lib/wild/`

```
Wild
├── Engine                        (Rails::Engine, isolate_namespace Wild)
├── Configuration                 (one block, nested accessors)
├── Error                         (base of consumer-distinguishable error tree)
├── Introspection                 (lib/wild/introspection/)
├── AdminTools                    (lib/wild/admin_tools/)
├── CapabilityGate                (lib/wild/capability_gate/)
├── Telemetry
│   ├── Collector                 (lib/wild/telemetry/collector/)
│   ├── Pipeline                  (lib/wild/telemetry/pipeline/)
│   └── Analysis                  (lib/wild/telemetry/analysis/)
├── Hooks                         (lib/wild/hooks/)
├── Analyzers
│   ├── Permission                (lib/wild/analyzers/permission/)
│   └── TestFlakes                (lib/wild/analyzers/test_flakes/)
└── Skillops                      (lib/wild/skillops/)
```

## Boundary discipline

Three layers enforce namespace integrity:

| Layer | Mechanism | What it catches |
|---|---|---|
| 1 | Packwerk (`packwerk.yml` + per-namespace `package.yml`; allowed-dependency graph in [ADR-0003](adr/ADR-0003-namespace-dependency-graph.md)) | Cross-namespace imports not declared in `dependencies:` |
| 2 | RuboCop (`.rubocop.yml`) | Forbidden constants, missing `# frozen_string_literal: true`, conventions |
| 3 | `# @api private` discipline | Symbols intended for internal use only; documented in CONTRIBUTING |

The Packwerk graph is a four-tier DAG (Hooks → Telemetry / Analyzers / Skillops → CapabilityGate → Introspection + AdminTools); see [ADR-0003](adr/ADR-0003-namespace-dependency-graph.md) for the canonical edge list and rationale per edge.

A new top-level namespace requires an ADR amendment to ADR-0001. A new inter-namespace edge requires an ADR amendment to ADR-0003. A new public API symbol on an existing namespace requires:

1. Removing the `# @api private` tag
2. Adding a CHANGELOG entry under that namespace's section
3. Adding an RSpec describing the public contract
4. PR review by the namespace's CODEOWNERS

## Configuration shape

One `Wild::Configuration` instance, exposed through `Wild.config`:

```ruby
# config/initializers/wild.rb
Wild.configure do |config|
  # Global
  config.audit_logger = Rails.logger
  config.environment  = Rails.env.to_sym

  # Per-namespace nested accessors
  config.introspection.access_policy_path =
    Rails.root.join("config/wild/access_policy.yml")
  config.introspection.allowed_models = nil  # nil = derive from policy

  config.admin_tools.cache_adapter = Rails.cache         # defaulted
  config.admin_tools.job_adapter   = ActiveJob::Base     # defaulted
  config.admin_tools.flag_adapter  = Flipper             # defaulted if Flipper is loaded

  config.capability_gate.capabilities_path =
    Rails.root.join("config/wild/capabilities.yml")
  config.capability_gate.on_evaluation_error = :hard_fail  # F2-mandated

  config.telemetry.collector.enabled = true
  config.telemetry.pipeline.sequence_strategy = :ingest_order
  config.telemetry.analysis.gap_threshold = 0.7

  config.hooks.lifecycle = :rails_engine  # vs. :standalone

  config.analyzers.permission.cycle_detection = :strict
  config.analyzers.test_flakes.classifier_corpus_path =
    File.expand_path("../wild/analyzers/test_flakes/golden_corpus.yml", __dir__)

  config.skillops.enabled = false  # internal namespace; off by default per F5
end
```

Council rev2 collapsed nine broken `Configuration` singletons into this single block. The old `freeze!`/`reset!` pattern is gone.

## Error hierarchy (Armstrong-mandated)

```
Wild::Error                              (base)
├── Wild::ConfigurationError             (invalid config)
├── Wild::CapabilityGate::Error          (base for gate)
│   ├── Wild::CapabilityGate::DeniedError
│   ├── Wild::CapabilityGate::PolicyError
│   └── Wild::CapabilityGate::EvaluationError    (F2 — never silent)
├── Wild::Introspection::Error
│   ├── Wild::Introspection::ForbiddenError
│   └── Wild::Introspection::ModelNotAllowedError
├── Wild::AdminTools::Error
├── Wild::Telemetry::Error
├── Wild::Hooks::Error
├── Wild::Analyzers::Error
└── Wild::Skillops::Error
```

Consumers can rescue at any level. Internal `rescue` clauses MUST be specific or re-raise after audit emission (F2).

## MCP transport entry points

Two MCP servers ship as `bin/` scripts. Each is a thin transport wrapper over a namespace:

```
bin/wild-mcp-introspection  →  Wild::Introspection
bin/wild-mcp-admin          →  Wild::AdminTools (always passes through Wild::CapabilityGate)
```

Tool descriptions live under `prompts/<tool>.md` and are versioned by filename. Changing a description is a reviewable code diff (Karpathy seam, council-mandated). Response shapes live under `schemas/<tool>.yml` (Hickey seam — schemas as data).

## Audit trail (F2 fix)

Every capability-gate decision path emits exactly one structured audit event:

```ruby
{
  timestamp:        ISO8601,
  decision_id:      UUID,
  capability:       :model_introspection,
  subject:          "agent:claude-code:abc",
  outcome:          :allow | :deny | :evaluation_error,
  policy_version:   "capabilities.yml@sha256:...",
  rationale:        "matched_rule:admin_introspection_read_only",
  audit_emit_ms:    1.2
}
```

`outcome: :evaluation_error` indicates an exception was rescued *inside* the gate. F2 makes this a hard-fail outcome (the request is denied) AND an audit event (no silence). Tests verify `:evaluation_error` against a deliberately broken policy fixture.

## Telemetry shape (F7 + F8 + Kleppmann compromise)

`Wild::Telemetry::Collector` ingests events. `Wild::Telemetry::Pipeline` normalizes them with a sequence number (Kleppmann's most-leveraged concession). `Wild::Telemetry::Analysis` consumes the normalized stream.

The fsync question: rev2 compromise is **either** fsync each append **or** drop "append-only audit log" framing from every README. v0.1.0 picks the latter for `Wild::Telemetry::Collector` (it's a process-local buffer, not a durable log). If a real durable-log consumer appears, fsync gates that consumer's gem (ADR-0002).

## Cross-namespace contract drift defense (F4)

Shared schemas live under `lib/wild/schemas/` (Hickey: schemas as data). Permission and capability-gate share `lib/wild/schemas/wildcard_corpus.yml` for matching tests, so the two analyzers can never drift on what counts as a wildcard.

## Test layout

One consolidated `spec/` tree, namespaced by module:

```
spec/
├── spec_helper.rb            (one SimpleCov config; coverage threshold)
├── wild/
│   ├── introspection/
│   ├── admin_tools/
│   ├── capability_gate/
│   ├── telemetry/
│   │   ├── collector/
│   │   ├── pipeline/
│   │   └── analysis/
│   ├── hooks/
│   ├── analyzers/
│   │   ├── permission/
│   │   └── test_flakes/
│   └── skillops/
├── engine/
│   ├── configuration_spec.rb
│   ├── error_spec.rb
│   └── install_generator_spec.rb
├── dummy/                    (a stub Rails app for engine integration tests)
└── support/
    ├── golden_corpora/       (Beck-mandated for test_flakes classifier)
    └── shared_examples/
```

`bundle exec rake test:<namespace>` runs one namespace's specs. The full suite is `bundle exec rspec`.

## What this architecture does NOT include

Per council rev2 deferral list:

- `Kafka`-shaped telemetry log
- Supervision tree / FallbackWriter (Puma is the supervisor at gem scale)
- 30-prompt agent-eval CI gate (seams ship; full eval is v2)
- TLA+ skillops formalization
- Cross-process audit-log shipping (single-process collector only in v0.1.0)
- Marketplace plugin registration (deferred to user's future private marketplace)
