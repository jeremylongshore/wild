# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Per-namespace changes are tracked under their own subsections so each namespace can
SemVer-stamp independently inside the single-gem package (council rev2 concession to
defense Point 3). When a namespace earns its own gemspec under
[ADR-0002](000-docs/adr/ADR-0002-namespace-extraction-policy.md), its CHANGELOG
section splits into a separate file.

## [Unreleased]

### Repo

- Pre-move coupling survey at `000-docs/008-AT-AUDT-pre-move-coupling-survey.md`. Static analysis of all 10 old `wild-*/lib/` trees against ADR-0003. **Finding: zero runtime cross-namespace constant coupling + zero cross-gem require statements.** Structural duplication (F1/F6/Wild::Hooks substrate emergence) identified and filed as 6 beads under their parent namespace epics: `wild-rvv.6.1` (MCP server scaffold → `Wild::Hooks::McpServer`), `wild-rvv.6.2` (audit-logging → `Wild::Hooks::Audit`), `wild-rvv.4.1.3` (capability_gate event.rb ↔ audit_event.yml), `wild-rvv.7.2` (coverage_analyzer dedup), `wild-rvv.5.4` + `wild-rvv.8.3` (F6 exporter audit). Role 5 entry checklist. Closes Role 4 PR-E.
- CONTRIBUTING.md § "Namespace-boundary discipline" expanded to cover the full ADR-0003 enforcement workflow: `# @api private` YARD discipline; new-public-symbol workflow (CHANGELOG + spec + CODEOWNERS); new-inter-namespace-edge workflow (ADR-0003 amendment); new-top-level-namespace workflow (ADR-0001 amendment); Packwerk-violation symptom-fix table; note on `lib/wild/schemas/` as the shared-data substrate. Role 4 PR-F.
- Schemas-as-data substrate landed under `lib/wild/schemas/`. Two files: `wildcard_corpus.yml` (F4 — shared wildcard matching corpus consumed by `Wild::Analyzers::Permission` AND `Wild::CapabilityGate`; 8 documented wildcard forms with `matches` + `non_matches` truth tables) and `capability_gate/audit_event.yml` (F2 — JSON Schema draft 2020-12 for the audit event shape; closed object with 8 required fields including the outcome enum `[allow, deny, evaluation_error]`). Specs verify structure + key fields; full matcher behavior + audit emission lives with Role 5/6. Closes F4 design portion (`wild-rvv.1.2`). Role 4 PR-D.
- `Wild::Error` consumer-distinguishable hierarchy: per-namespace `Wild::<Namespace>::Error` base + targeted subclasses (`CapabilityGate::{DeniedError,PolicyError,EvaluationError}`, `Introspection::{ForbiddenError,ModelNotAllowedError}`, `AdminTools::Error`, `Telemetry::Error`, `Hooks::Error`, `Analyzers::Error`, `Skillops::Error`). Matches `000-docs/003-AT-ARCH-architecture.md § Error hierarchy` verbatim. Closes MIN-Armstrong (`wild-rvv.1.3`). Role 4 PR-C.
- Typed `Wild::Configuration` nested accessors with declared settings classes per namespace (`Introspection`, `AdminTools`, `CapabilityGate`, `Telemetry::{Collector,Pipeline,Analysis}`, `Hooks`, `Analyzers::{Permission,TestFlakes}`, `Skillops`); replaces the `OpenStruct`-based `method_missing` stub. Closes F1 design + initial implementation (`wild-rvv.1.1`). Per-namespace defaults: `on_evaluation_error: :hard_fail` (F2-mandated), `skillops.enabled: false` (F5), `telemetry.analysis.gap_threshold: 0.7`, etc. Role 4 PR-B.
- Initial project setup with full governance (README, LICENSE, CODE_OF_CONDUCT, CONTRIBUTING, SECURITY, SUPPORT, CLAUDE.md, AGENTS.md, EditorConfig, gitattributes)
- CI workflow (Ruby 3.2 + 3.3 + 3.4 matrix; RSpec, RuboCop, Packwerk, brakeman, bundler-audit; Codecov upload)
- Release workflow (workflow_dispatch only — no auto-release on push; v0.1.0 ships at end of the 4-week consolidation build)
- CodeQL static analysis workflow (`security-extended` suite on `ruby` + `actions`; weekly schedule; repo-specific `.github/codeql/codeql-config.yml`); strategy documented at `000-docs/007-AT-STND-codeql-strategy.md`
- Dependabot for bundler + GitHub Actions
- Issue templates (bug, feature) + PR template
- CODEOWNERS, FUNDING
- Ruby gem skeleton: `wild.gemspec`, Gemfile, Rakefile, `bin/console`, `bin/setup`
- Engine skeleton: `lib/wild.rb`, `lib/wild/engine.rb`, `lib/wild/version.rb`, `lib/wild/error.rb`, `lib/wild/configuration.rb`
- Namespace directory placeholders under `lib/wild/`
- ADR-0001 (topology — one gem, ten namespaces)
- ADR-0002 (namespace extraction policy)
- ADR-0003 (namespace dependency graph — four-tier DAG; Role 4 PR-A)
- Root `package.yml` + ten per-namespace `package.yml` files encoding the ADR-0003 dependency contract; `packwerk.yml` lists each package path
- 6-doc enterprise planning set under `000-docs/`

### Wild::Introspection

- Moved 23 source files from `wild-rails-safe-introspection-mcp/lib/wild_rails_safe_introspection/`
  into `lib/wild/introspection/` under the `Wild::Introspection::*` namespace
  (Role 5 PR-11). Sub-directories preserved: `identity/`, `guard/`, `adapter/`,
  `audit/`, `server/` (+ `server/tools/`). Module Zeitwerk-rewritten from
  compact form. New loader at `lib/wild/introspection.rb` carries the
  `.configure` / `.configuration` / `.reset!` accessors from the old gem entry.
- 30 specs (unit + safety + adversarial + integration) moved to
  `spec/wild/introspection/`. The gem tests against a live in-memory
  ActiveRecord schema — `spec/spec_helper.rb` now establishes a throwaway
  sqlite connection and loads the moved `test_schema` + `test_models` (global
  but harmless to non-AR namespaces). `TestConfigHelper` rewrapped as
  `Wild::Introspection::TestSupport::TestConfigHelper` and included +
  `Wild::Introspection.reset!` / `ConnectionManager.reset!` before-hook both
  `file_path`-scoped to introspection specs. Access-policy fixtures moved to
  `spec/support/wild_introspection/fixtures/`.
- **Configuration kept as a namespace object, NOT folded into the central
  struct** (`wild-rvv.u16`). The gem's `Configuration` is a YAML policy loader
  (`access_policy.yml` → per-model blocked columns / allowed models), not a
  settings bag — collapsing it into `Wild::Configuration::Introspection` would
  be a behavior change. It moves as `Wild::Introspection::Configuration` with
  the `.configuration` accessor preserved; wiring the central typed struct's
  `access_policy_path` into this loader at engine boot is a deferred Role 6/8
  task (parallels admin_tools' `wild-rvv.3.1` adapter resolution). F1 still
  holds — F1 closed the nine *settings-bag* singletons, which this is not.
- **MIN-Armstrong — `Wild::Introspection::Error` subtree extended** with the
  gem's `ConfigError`, `WriteAttemptError`, `QueryTimeoutError` (alongside the
  PR-C `ForbiddenError` + `ModelNotAllowedError`). The gem's bare
  `Error < StandardError` is replaced by `Wild::Introspection::Error <
  Wild::Error` — still a StandardError descendant, so consumer rescue behavior
  is preserved. `version.rb` deleted (F1); `server_factory` + `audit_record`
  metadata `version:` → `Wild::VERSION`.
- **NOT in this PR** (deferred per Beck Tidy-First / anti-scope): refactoring
  `server/` to consume the `Wild::Hooks::McpServer` substrate and wiring the
  `bin/wild-mcp-introspection` entry point are Role 9 (MCP/AI-seams); wiring
  the gem's `Identity::CapabilityGate` *stub* to the real `Wild::CapabilityGate`
  is a behavior change for a follow-up. The `server/` code moves verbatim.

### Wild::AdminTools

- Moved 39 source files from `wild-admin-tools-mcp/lib/wild_admin_tools_mcp/`
  into `lib/wild/admin_tools/` under the `Wild::AdminTools::*` namespace
  (Role 5 PR-12 — **the final namespace move; completes the 10-namespace
  consolidation**). Sub-directories preserved: `executor/` (+ `adapters/`),
  `guard/`, `confirmation/`, `audit/`, `identity/`, `server/` (+ `tools/`).
  Module Zeitwerk-rewritten from compact form. New loader at
  `lib/wild/admin_tools.rb` carries the `.configure` / `.configuration` /
  `.reset_configuration!` accessors.
- 39 specs (unit + safety + adversarial + integration) + 5 support files
  moved to `spec/wild/admin_tools/` and `spec/support/wild_admin_tools/`.
  `PolicyFixtures` + `SafetyHelpers` included `file_path`-scoped; a scoped
  `Wild::AdminTools.reset_configuration!` before-hook; `shared_examples`
  required globally. Three specs' stale `require_relative '../../support/test_gate'`
  lines removed (spec_helper loads support globally now).
- **MIN-Armstrong — `Wild::AdminTools::Error` subtree** built with the gem's
  custom-initializer errors: `ActionNotFoundError` (carries `action_name`),
  `ValidationError` (carries `errors`), `AdapterError` + `GateError` (carry
  `original_error`), `AuthenticationError`. The gem's bare `Error < StandardError`
  becomes `Wild::AdminTools::Error < Wild::Error` (rescue behavior preserved);
  its `ConfigurationError` subsumed by `Wild::ConfigurationError`. `version.rb`
  deleted (F1); `audit/record` + `server_factory` version metadata →
  `Wild::VERSION`.
- **Configuration kept as a namespace object** (`wild-rvv.uku`). The gem's
  `Configuration` holds dependency-injection points (`cache_adapter`,
  `job_adapter`, `flag_adapter`, `gate`, `policy_path`, `audit_log_path`,
  `audit_store` — all nil-default). It moves as `Wild::AdminTools::Configuration`
  with the `.configuration` accessor preserved. Reconciling these nil-default
  injection points with PR-B's central `Wild::Configuration::AdminTools`
  `:default` sentinels — **the "kill the DI container" adapter-defaulting at
  engine boot** — is deferred to Role 8 (overlaps `wild-rvv.3.1`). Mirrors the
  introspection `wild-rvv.u16` decision; F1 still holds.
- **NOT in this PR** (anti-scope): refactoring `server/` to consume
  `Wild::Hooks::McpServer` + wiring `bin/wild-mcp-admin` is Role 9 (MCP
  transport); the DI-container adapter-defaulting is Role 8. The `server/`
  code + the `gate`-injection wiring move verbatim.

### Wild::CapabilityGate

- **F2 audit-emission ordering pinned + a residual silent-denial hole closed**
  (Role 6 PR-5, `wild-rvv.4.1.1`; Armstrong F2 gate **SIGN-OFF**):
  - **Ordering spec (the bead deliverable):** the audit-liveness suite proved
    the error event is emitted (count + payload) but not its *ordering*. Added
    examples that pin **emit-completes-before-the-denial-returns** via a
    sequence-recording writer; proven to bite (reorder the rescue to
    return-before-emit → 2 red). The bead's original "re-raise" framing predated
    the shipped fail-closed contract — `evaluate` denies, never raises — so the
    invariant is "emit before the terminal *return*", the same audit-completeness
    guarantee. Spec documents the guarantee is synchronous-writer-scoped (async
    writers need a separate durability invariant — `wild-28y`).
  - **Closed a residual silent-denial path (Armstrong Finding 2, fixed in-PR):**
    a hostile `caller_id` whose `#to_s` raises blew up the first coercion in
    `evaluate`; the rescue then re-coerced the same object in
    `deny_evaluation_error`, **raising a second time inside the rescue handler**
    → `evaluate` propagated an exception with no audit written. Now coerced via
    a never-raising `SafeCoercion` collaborator (`safe_symbol` → `:unknown`,
    `safe_caller_id` → `"<uncoercible-caller-id>"`), so the gate still fails
    closed, still audits, and never raises on malformed input. Pinned by 4 new
    examples.
  - **Doc-truth fixes:** the `CapabilityGate::EvaluationError` docstring no
    longer claims the error is "raised" (it is declared but never raised — the
    gate denies); the inert `on_evaluation_error: :hard_fail` config default now
    carries an inline "CURRENTLY INERT" warning so no operator infers raise
    semantics. Both reconciled under decide-or-cut `wild-28y`. Armstrong's
    dark-audit-ALLOW posture finding filed as `wild-0c3` (P1).
- **F2 audit-emission fix (council rev2, Armstrong)** — closes the two
  audit-blind paths the council named (Role 6 PR-1, `wild-rvv.4.1`):
  - **Evaluation that raises now leaves an audit trail.** `Evaluator#evaluate`
    wraps its decision logic in a rescue: on any `StandardError` it fails
    closed (denies with reason `:evaluation_error`) AND emits the matching
    audit event before returning. Previously a raise propagated to
    `Gate#evaluate`'s rescue, which denied but emitted nothing — a silent
    denial. The prerequisite checkers are already fail-closed, so this is
    defense-in-depth against a corrupted registry/grant or a future checker bug.
  - **Audit-pipeline failure is no longer doubly silent.** `Evaluator#emit_audit`
    previously swallowed write failures to `nil`. It now logs them to
    `Wild.config.audit_logger.error` (still never raises — a broken audit log
    must not break the gate). Only a simultaneous writer-AND-logger outage is
    terminally silent.
  - `Audit::Event` gains a third result value, `evaluation_error` (distinct
    from `denied`), so audit readers can tell "policy said no" apart from "the
    gate broke and failed closed". `:evaluation_error` is always a denial
    (hard-fail intrinsic to `EvaluationResult.denied`).
  - New `spec/wild/capability_gate/audit/audit_liveness_spec.rb` (8 examples)
    proves the property under deliberate corruption: an exploding registry →
    asserts denial + reason `:evaluation_error` + exactly one emitted event
    with `result: "evaluation_error"`; an exploding writer → asserts no raise,
    allow-result preserved, and the failure logged to the audit logger.
  - **NOT in this PR** (separate `wild-rvv.4.1` children): the full
    `audit_event.yml` schema migration — `decision_id` / `policy_version` /
    `audit_emit_ms` (`wild-rvv.4.1.3`), and the json-schema validator wiring
    (`wild-rvv.4.1.2`). This PR uses the existing event shape + the new
    `evaluation_error` result value.
- Moved 18 source files from `wild-capability-gate/lib/wild/capability_gate/`
  into `lib/wild/capability_gate/` under the existing `Wild::CapabilityGate`
  namespace. The source gem already used proper lexical module nesting and
  the correct `lib/wild/capability_gate/` path layout, so the move is
  effectively a copy + entry-loader cleanup with no namespace renames.
  Layout preserved verbatim: `audit/`, `evaluator/`, `prerequisites/`,
  `registry/`, `session/` sub-directories. Closes `wild-rvv.4` base move
  (Role 5 PR-4).
- Moved 18 spec files (unit + integration + safety + governance) to
  `spec/wild/capability_gate/{,integration,safety}/`. 11 YAML fixtures
  moved to `spec/fixtures/`. Three specs had their fixture-resolution
  paths updated from `'../fixtures/config'` to `'../../../fixtures/config'`
  to account for the deeper nesting under `spec/wild/capability_gate/`.
- Deleted the duplicate `version.rb` (F1 — gem version is canonical at
  `Wild::VERSION`). Updated `spec/wild/capability_gate_spec.rb` smoke
  test to assert `Wild::VERSION` instead of the removed
  `Wild::CapabilityGate::VERSION`.
- The `Wild::CapabilityGate::Error` hierarchy (DeniedError, PolicyError,
  EvaluationError) already exists from PR-C (MIN-Armstrong) — the moved
  code's three internal error classes (`Registry::DuplicateCapabilityError`,
  `Registry::ConfigLoader::ConfigError`, `Evaluator::GrantLoader::GrantConfigError`)
  remain as-is per Beck Tidy-First (re-parenting them to `PolicyError`
  would be a behavior change for a follow-up).
- F2 audit-blind fix is **explicitly NOT in this PR** — that's `wild-rvv.4.1`
  (Role 6). This PR is the structure-only move that Role 6's behavior
  change lands on top of, per Role 5 doc § "Validation gate".

### Wild::Telemetry::Collector

- Moved 13 source files from `wild-session-telemetry/lib/wild_session_telemetry/`
  into `lib/wild/telemetry/collector/` under the 3-deep
  `Wild::Telemetry::Collector::*` namespace (Role 5 PR-8; first of three
  Telemetry sub-namespace moves — Pipeline + Analysis follow). Sub-directories
  preserved: `schema/`, `store/`, `privacy/`, `collector/`, `export/`,
  `aggregation/`. Module Zeitwerk-rewritten from compact form. New loader at
  `lib/wild/telemetry/collector.rb`. (The gem's internal `collector/`
  submodule nests as `Collector::Collector::EventReceiver` — behavior-preserving;
  any flatten/rename is a deferred behavior change.)
- 17 specs (unit + adversarial + integration) moved to
  `spec/wild/telemetry/collector/`. `EventFixtures` rewrapped as
  `Wild::Telemetry::Collector::TestSupport::EventFixtures`, wired into spec_helper.
- **F1 — `Wild::Configuration::Telemetry::Collector` extended** from 1 setting
  (`enabled` from PR-B) to 5: the 4 old-gem knobs (`store`, `retention_days`
  90, `privacy_mode` :strict, `max_storage_bytes`) plus `enabled`. Defaults
  verbatim. Deleted `version.rb` + `configuration.rb`; orphaned
  `configuration_spec.rb` removed (coverage folded into central config spec).
- **MIN-Armstrong — `Wild::Telemetry::Collector::Error` subtree added**:
  `ValidationError`, `SchemaError`, `StorageError`. Old gem's
  `ConfigurationError` subsumed by `Wild::ConfigurationError`.
- Config setter validation + freeze!/frozen? machinery NOT carried over;
  4 freeze/immutability adversarial specs (doc-005 Rule 8, doc-006 Threat 7)
  deleted per F3 (no vanity tests of absent behavior). Rationale inline.
- Pre-existing complexity in the moved aggregation/export code tripped wild's
  stricter Metrics config — localized inline disables per site (no refactor;
  behavior-preserving move).
- **NOT in this PR** (deferred per Beck Tidy-First, all `wild-rvv.5` children):
  F7 boundary normalization (`5.1`), F8 decomplect identity/value/time (`5.2`),
  MIN-Kleppmann append-only-log fsync decision (`5.3`), F6 export audit (`5.4`).

### Wild::Telemetry::Pipeline

- Moved 16 source files from `wild-transcript-pipeline/lib/wild_transcript_pipeline/`
  into `lib/wild/telemetry/pipeline/` under the 3-deep
  `Wild::Telemetry::Pipeline::*` namespace (Role 5 PR-9; second of three
  Telemetry sub-namespace moves). Sub-directories preserved: `ingestion/`,
  `normalization/`, `privacy/`, `models/`, `export/`. Module Zeitwerk-rewritten
  from compact form. New loader at `lib/wild/telemetry/pipeline.rb` carries the
  `Wild::Telemetry::Pipeline.process` convenience method (full ingest →
  normalize → redact pipeline) from the old gem entry point.
- 19 specs (unit + adversarial + integration) moved to
  `spec/wild/telemetry/pipeline/`. `TranscriptFixtures` rewrapped as
  `Wild::Telemetry::Pipeline::TestSupport::TranscriptFixtures`, wired into
  spec_helper. Spec `WildTranscriptPipeline.process` calls + flat config
  setters rewritten to the nested API.
- **F1 — `Wild::Configuration::Telemetry::Pipeline` extended** from 1 setting
  (`sequence_strategy` from PR-B) to 8: the 7 old-gem knobs
  (`intent_confidence_threshold` 0.5, `max_turn_content_length` 10_000,
  `max_turns_per_transcript` 1_000, `redaction_marker` "[REDACTED]",
  `strip_absolute_paths` true, `strip_file_contents` true, `custom_patterns`
  []) plus `sequence_strategy`. Defaults verbatim. Deleted `version.rb` +
  `configuration.rb`; `json_exporter` metadata `version:` → `Wild::VERSION`;
  orphaned `configuration_spec.rb` removed.
- **MIN-Armstrong — `Wild::Telemetry::Pipeline::Error` subtree added**:
  `IngestionError`, `NormalizationError`, `PrivacyError`, `ExportError`. Old
  gem's `ConfigurationError` subsumed by `Wild::ConfigurationError`.
- Pre-existing complexity (`Transcript` value-object ParameterLists,
  `tool_extractor` AbcSize) handled with localized inline disables — no
  refactor (behavior-preserving move).
- **NOT in this PR** (deferred, `wild-rvv.5` children): F7 (`5.1`), F8 (`5.2`),
  MIN-Kleppmann (`5.3`), F6 export audit (`5.4`).

### Wild::Telemetry::Analysis

- Moved 25 source files from `wild-gap-miner/lib/wild_gap_miner/` into
  `lib/wild/telemetry/analysis/` under the 3-deep
  `Wild::Telemetry::Analysis::*` namespace (Role 5 PR-10; **completes the
  three-gem `wild-rvv.5` Telemetry epic structure**). Sub-directories
  preserved: `models/`, `ingestion/`, `analyzers/`, `scoring/`,
  `recommendations/`, `report/`, `export/`. Module Zeitwerk-rewritten from
  compact form. New loader at `lib/wild/telemetry/analysis.rb` carries the
  `Wild::Telemetry::Analysis.analyze` convenience method (parse export →
  build gap report) from the old gem entry point.
- 25 specs (unit + adversarial + integration) moved to
  `spec/wild/telemetry/analysis/`. `TelemetryFixtures` rewrapped as
  `Wild::Telemetry::Analysis::TestSupport::TelemetryFixtures`; `HEADER_DATA`
  constant refs + flat config setters rewritten to the nested API.
- **F1 — `Wild::Configuration::Telemetry::Analysis` extended** from 1 setting
  (`gap_threshold` from PR-B) to 9: the 8 old-gem thresholds (`denial_threshold`
  0.2, `failure_threshold` 0.15, `latency_p95_threshold_ms` 500.0,
  `utilization_min_count` 5, `coverage_min_fraction` 0.3,
  `pattern_min_occurrences` 3, `max_gaps_per_type` 50, `severity_weights`
  all-1.0 six-signal map) plus `gap_threshold`. Defaults verbatim from the
  gem's DEFAULTS hash. Deleted `version.rb` + `configuration.rb`; orphaned
  `configuration_spec.rb` removed.
- **MIN-Armstrong — `Wild::Telemetry::Analysis::Error` subtree added**:
  `ParseError`, `ValidationError`, `SchemaError`, `ExportError`. Old gem's
  `ConfigurationError` subsumed by `Wild::ConfigurationError`.
- **Fixture isolation fix** — all per-namespace fixture modules are now
  `config.include`d scoped by `file_path` (not globally). `build_event`
  collided between `Wild::Hooks::TestSupport::HookFixtures` and the telemetry
  `TelemetryFixtures`; global includes let the last-loaded shadow the rest.
  Path-scoping binds each namespace's helpers to its own specs.
- Pre-existing complexity (`coverage_analyzer` AbcSize, `Gap` ParameterLists)
  handled with localized inline disables — no refactor.
- **NOT in this PR** (deferred, `wild-rvv.5` children): F7 (`5.1`), F8 (`5.2`),
  MIN-Kleppmann (`5.3`), F6 export audit (`5.4`). Config validation + freeze
  machinery dropped; 8 validation/freeze adversarial specs deleted per F3.

### Wild::Hooks

- **Audit substrate extension landed** — closes the structural-duplication
  portion of `wild-rvv.6.2`. Two new classes/modules under the existing
  `Wild::Hooks::Audit` namespace (which already hosts `Trail` + `Logger`
  from PR #20):
  - `Wild::Hooks::Audit::Sanitizer` — generic key-pattern parameter
    sanitizer extracted from `wild-admin-tools-mcp`'s reusable design.
    Configurable `redact_keys` (defaults cover password / secret /
    token / api_key / private_key / ssn / credit_card / email / phone /
    address) and `hash_keys` (defaults: job_id / actor_id / user_id /
    account_id → SHA-256 fingerprint). Recurses into nested hashes,
    does not mutate input. Introspection's per-tool dispatch sanitizer
    stays in `Wild::Introspection::Audit::*` (different shape entirely)
    and can wrap this Sanitizer for its redaction layer when that
    namespace moves.
  - `Wild::Hooks::Audit::Timer` — `Process::CLOCK_MONOTONIC` wrapper
    that both old gems inlined inline at every emission site. Provides
    `.now` + `.elapsed_ms(start)` for measuring `audit_emit_ms` (F2
    audit-liveness metric per architecture doc). Consumed by the F2
    emitter Wild::CapabilityGate will use when wild-rvv.4.1 lands.
  - The two `recorder.rb` files in introspection + admin_tools were
    intentionally NOT pulled up — they're too divergent (hash-result vs
    object-result, swallow-errors vs re-raise, different domain attrs).
    Forcing them together would be a false abstraction.
- **MCP server substrate landed** (`Wild::Hooks::McpServer`) — Tier 1
  transport substrate per ADR-0003. Two public APIs:
  - `Wild::Hooks::McpServer::Factory.create(name:, version:, tools:, server_context: {})`
    consolidates the `MCP::Server.new(...)` boilerplate that lived
    independently in `wild-rails-safe-introspection-mcp` and
    `wild-admin-tools-mcp`.
  - `Wild::Hooks::McpServer::ToolHandler.wrap { ... }` consolidates the
    `rescue StandardError` outer wrapper that both gems' `ToolHandler.execute`
    paths had. Per-namespace identity / capability-gate / pipeline logic
    STAYS in the namespaces; only the rescue + format-via-callback pattern
    is shared (consumer supplies `error_formatter:`).
  - `mcp ~> 0.8` added as a runtime dependency (was already a runtime dep
    in both old gems' gemspecs).
  - Closes the substrate-extraction portion of wild-rvv.6.1. When the
    introspection + admin_tools moves land in their respective Role 5 PRs,
    they will consume this substrate and drop their own duplicates.
- Moved 14 source files from `wild-hook-ops/lib/wild_hook_ops/` into
  `lib/wild/hooks/` under the `Wild::Hooks::*` namespace (Role 5 PR-1).
  Layout preserved verbatim: `models/`, `registry/`, `execution/`,
  `lifecycle/`, `health/`, `audit/` sub-directories with the same files,
  just renamed at the module level. Loader at `lib/wild/hooks.rb` replaces
  the old `wild_hook_ops.rb` entry point.
- 16 specs + 1 integration + 1 adversarial + 1 fixtures module moved to
  `spec/wild/hooks/` and `spec/support/wild_hooks/`. `Wild::Hooks::TestSupport::HookFixtures`
  wired into `spec/spec_helper.rb`.
- Collapsed the old `WildHookOps::Configuration` class into
  `Wild::Configuration::Hooks` (F1). Seven knobs now on `Wild.config.hooks`:
  `default_timeout_ms` (5000), `max_handlers_per_hook` (20), `enable_audit_logging`
  (true), `max_audit_entries` (10_000), `execution_mode` (:sequential),
  `on_handler_error` (:log_and_continue), `lifecycle` (:rails_engine).
  Defaults preserved verbatim from the old gem. The old gem's per-setter
  type validation + `freeze!`/`frozen?` machinery is NOT carried over —
  filed as Role 6 follow-up under wild-rvv.6.
- Collapsed the old `WildHookOps` error tree (6 classes) into the
  `Wild::Hooks::Error` hierarchy (MIN-Armstrong). Four subclasses now under
  `Wild::Hooks::Error`: `HookNotFoundError`, `DuplicateHookError`,
  `HandlerLimitExceededError`, `InvalidHandlerError`. The old gem's
  `InvalidConfigurationError` + `ConfigurationFrozenError` are subsumed by
  `Wild::ConfigurationError` (Wild engine no longer freezes config — by
  design per architecture doc).
- Closes wild-rvv.6 base move. The two children (wild-rvv.6.1 MCP server
  scaffold + wild-rvv.6.2 audit-logging) remain open — they extract shared
  patterns from the introspection + admin_tools gems into this same
  namespace in follow-up PRs.

### Wild::Analyzers::Permission

- **F4 anti-drift fence landed + corpus reconciled to the real grammar**
  (Role 6 PR-3; `wild-rvv.1.2.1` + `wild-lkp`). The shared
  `lib/wild/schemas/wildcard_corpus.yml` (Role 4 PR-D) described a `::`-segmented
  grammar with 8 forms + segment-boundary semantics that **neither shipped
  matcher implemented**, in a notation that doesn't match the real dotted/flat
  capability names. Per the "code is truth" reconciliation:
  - **Corpus rewritten (v1 → v2)** to the dotted-glob grammar
    `Wild::Analyzers::Permission::Analyzers::WildcardMatcher` actually implements
    (exact; trailing `admin.jobs.*`; prefix `admin.*`; middle `admin.*.retry`;
    universal `*`). Truth tables verified against the live matcher's real
    (greedy `*`→`.*`, no segment-boundary) behaviour — `admin.jobs.*` matches the
    deeper `admin.jobs.retry.force`; universal `*` matches every string incl `""`.
  - **New corpus-driven smoke spec** (`wildcard_corpus_matcher_spec.rb`) runs the
    matcher against every entry's `matches[]`/`non_matches[]` — the actual
    anti-drift fence; red if the matcher drifts from the documented grammar.
  - **Escaping-contract rows pinned** (Hickey F4 gate, Finding 1): the corpus now
    pins the grammar's *defining* constraint, not just its happy path — `*` is the
    SOLE metacharacter (every other char is a literal, because `Regexp.escape`
    runs before the `*`→`.*` substitution), and `*` is zero-or-more. Rows for
    `.*` (leading-dot-literal, NOT universal), `a.b`/`a+b` (literal dot/plus),
    `a*c` + `admin.jobs.` (zero-width `*`). Fence verified by mutation: dropping
    `Regexp.escape` → 2 red; `.*`→`.+` → 3 red. Reviewer follow-ups filed as
    `wild-96t` (schema-spec non_matches invariant) + `wild-yms` (centralize
    wildcard *detection*). Schema-as-data seam signed off by `rich-hickey-reviewer`.
  - **Scope decision**: capability-name wildcard matching lives in exactly ONE
    namespace (Permission). `Wild::CapabilityGate` is exact-symbol-match BY
    DESIGN — its only wildcard is the *caller* `*` (a different axis). The
    council F4 "the two must not disagree" is satisfied vacuously — there is one
    capability-name matcher. Documented in `grant.rb` + pinned by new
    `grant_spec` cases. The richer `::` grammar, if ever wanted, is a deliberate
    matcher change with its own ADR — not a silent expectation.
- **`detect_cycle` false-positive fixed** (Fowler review findings 1 + 10 —
  his most-costly-to-recover-from finding; Role 6 PR-2, `wild-jzg` under
  `wild-rvv.7`). `PrerequisiteAnalyzer#detect_cycle` used a
  `depth > max_prerequisite_depth` short-circuit that fabricated a
  `:circular_prerequisite/critical` finding for ANY acyclic chain deeper than
  the limit (default 10) — "a security tool that invents critical findings
  teaches operators to ignore critical findings." It also re-discovered each
  real cycle once per node on it (path-local `visited` + per-node re-entry).
  Replaced with an **iterative tri-color DFS** (WHITE/GRAY/BLACK global state,
  explicit frame stack — no recursion-depth ceiling): a back-edge to a GRAY
  (on-stack) node is the only cycle signal, and each ring is reported exactly
  once via a rotation-invariant signature. The depth limit is gone (it was the
  bug, not a safety feature).
- **`max_prerequisite_depth` config knob removed** (`wild-0e0`, Fowler+Hickey
  decide-or-cut follow-up on the detect_cycle fix). Tri-color DFS left the knob
  wired to nothing. Per the reviewers' own framing — "dead config erodes trust
  in live config; the next operator sets it expecting an effect, gets none,
  distrusts the whole config surface" — it was **cut**, not left inert. Dropped
  the `Wild::Configuration::Analyzers::Permission` struct member + its default,
  the "defaults to 10" + "accepts 1" spec assertions, and the
  "even with the knob set low" cycle-guard variant. A future "warn beyond
  operational depth" finding, if ever wanted, is a clean additive feature (new
  knob + `:warning` finding) under its own bead — not a speculatively-reserved
  hook. CTO call: option (a) delete over option (b) build-the-feature, per the
  "no speculative infrastructure" build principle.
- **Test discipline** (Beck + Fowler gate): the former
  "max_prerequisite_depth prevents infinite loops" example — which built a
  15-deep acyclic chain, set the limit to 5, and asserted only `not_to
  raise_error`, thereby documenting the false positive as a feature — was
  **deleted**. Replaced with: a 15-deep-straight-line guard (zero
  `:circular_prerequisite` findings), 2-node +
  3-node cycle "reported exactly once" specs, a diamond (shared-but-acyclic)
  guard, and a `full_audit_spec` integration test proving a deep acyclic chain
  yields zero critical findings. All written failing-first against the buggy
  code, then green after the fix.
- Moved 17 source files from `wild-permission-analyzer/lib/wild_permission_analyzer/`
  into `lib/wild/analyzers/permission/` under the 3-deep `Wild::Analyzers::Permission::*`
  namespace (Role 5 PR-6). Sub-directories preserved: `models/`, `loaders/`,
  `analyzers/`, `report/`, `export/`. Module rewritten from compact
  `module WildPermissionAnalyzer` to nested `module Wild; module Analyzers;
  module Permission` (Zeitwerk-compatible, same fix as PR #20). New loader at
  `lib/wild/analyzers/permission.rb` carries the `Wild::Analyzers::Permission.audit`
  convenience method from the old gem entry point.
- 22 specs (unit + adversarial + integration) moved to
  `spec/wild/analyzers/permission/`. Fixtures module rewrapped as
  `Wild::Analyzers::Permission::TestSupport::Fixtures`, wired into spec_helper.
- **F1 — `Wild::Configuration::Analyzers::Permission` extended** from 1 setting
  (`cycle_detection` from PR-B) to 6: the 5 old-gem knobs (`capabilities_path`,
  `grants_path`, `risk_levels` four-tier severity map, `wildcard_risk_threshold`
  "medium", `max_prerequisite_depth` 10) plus `cycle_detection`. Defaults
  preserved verbatim. Deleted the old gem's `version.rb` + `configuration.rb`;
  the orphaned `configuration_spec.rb` was removed and its coverage folded
  into the central `spec/wild/configuration_spec.rb`.
- **MIN-Armstrong — `Wild::Analyzers::Permission::Error` subtree added**:
  `LoadError`, `AnalysisError`, `ExportError` under
  `Wild::Analyzers::Permission::Error < Wild::Analyzers::Error`. The old gem's
  `ConfigurationError` is subsumed by `Wild::ConfigurationError`.
- Export pair retained to preserve coverage during the move — the F6
  wire-or-delete audit lives at `wild-rvv.5.4`.
- Config-setter validation + freeze/frozen? machinery NOT carried over (Wild's
  no-freeze design); the 2 adversarial tests covering those features were
  deleted per F3 (no vanity tests of absent behavior). Rationale inline.
- **NOT in this PR** (deferred per Beck Tidy-First): the Fowler `detect_cycle`
  false-positive fix and the F3 vanity-test replacement — both are Role 6/7
  behavior changes under `wild-rvv.7`'s children (`wild-rvv.7.1`).

### Wild::Analyzers::TestFlakes

- Moved 21 source files from `wild-test-flake-forensics/lib/wild_test_flake_forensics/`
  into `lib/wild/analyzers/test_flakes/` under the 3-deep
  `Wild::Analyzers::TestFlakes::*` namespace (Role 5 PR-7). Sub-directories
  preserved: `models/`, `parsers/`, `detection/`, `analysis/`, `triage/`,
  `history/`, `export/`. Module Zeitwerk-rewritten from compact
  `module WildTestFlakeForensics` to nested form. New loader at
  `lib/wild/analyzers/test_flakes.rb`.
- 24 specs (unit + adversarial + integration) moved to
  `spec/wild/analyzers/test_flakes/`. Fixtures module (`TestFixtures`)
  rewrapped as `Wild::Analyzers::TestFlakes::TestSupport::Fixtures`; spec
  references to the old `TestFixtures::BASE_TIMESTAMP` constant rewritten to
  the new path; wired into spec_helper.
- **F1 — `Wild::Configuration::Analyzers::TestFlakes` extended** from 1 setting
  (`classifier_corpus_path` from PR-B) to 5: the 4 old-gem knobs (`minimum_runs`
  3, `flake_rate_threshold` 0.1, `max_history_entries` 10_000, `severity_weights`
  all-1.0 four-signal map) plus `classifier_corpus_path`. Defaults verbatim.
  Deleted the old gem's `version.rb` + `configuration.rb`; orphaned
  `configuration_spec.rb` removed (coverage folded into central config spec).
  `json_exporter.rb`'s metadata `version:` now reads `Wild::VERSION`.
- **MIN-Armstrong — `Wild::Analyzers::TestFlakes::Error` subtree added**:
  `ParseError`, `DetectionError`, `ExportError`. Old gem's `ConfigurationError`
  subsumed by `Wild::ConfigurationError`.
- 3 export files (`json`, `markdown`, `summary`) retained — F6 wire-or-delete
  audit (Beck named 2 of 3 as half-published) is `wild-rvv.5.4`.
- Config setter validation + freeze!/frozen? machinery NOT carried over; the
  freeze adversarial spec deleted per F3.
- **NOT in this PR** (deferred per Beck Tidy-First): the F3 golden-corpus
  classifier test (`wild-rvv.7.1`) and the `coverage_analyzer` dedup between
  Permission + TestFlakes (`wild-rvv.7.2`).

### Wild::Skillops

- Moved 20 source files from `wild-skillops-registry/lib/wild_skillops_registry/`
  into `lib/wild/skillops/` under the `Wild::Skillops::*` namespace (Role 5
  PR-5). Layout preserved verbatim: `models/`, `registry/`, `versioning/`,
  `governance/`, `discovery/`, `health/`, `export/` sub-directories.
  Module renamed from `WildSkillopsRegistry` to `Wild::Skillops` via
  Zeitwerk-nested rewrite (same pattern as PR #20 for Wild::Hooks). New
  loader at `lib/wild/skillops.rb` carries the `Wild::Skillops.build`
  factory + `RegistryFacade` class from the old gem entry point.
- 24 specs (unit + 2 adversarial + 2 integration) moved to
  `spec/wild/skillops/`. Fixtures module (`RegistryFixtures`) rewrapped as
  `Wild::Skillops::TestSupport::Fixtures` and wired into spec_helper.
- **F5 partial — `Wild::Configuration::Skillops` extended** from 1 setting
  (`:enabled`) to 6 (the 5 old-gem knobs: `max_skills` 1000, `max_versions_per_skill`
  50, `health_stale_threshold_hours` 24, `allowed_lifecycle_states`
  [:draft, :active, :deprecated, :retired], `allowed_health_states`
  [:available, :degraded, :unavailable, :unknown]). Defaults preserved
  verbatim. The F5 README/doc downgrade (removing the "atomic" / "durable"
  claims Lamport flagged) remains a separate Role 6 bead — `wild-rvv.8.1`.
- **F1 + MIN-Armstrong applied** — deleted the old gem's `version.rb` (one
  `Wild::VERSION` at gem level); collapsed the 7-class error tree into 6
  subclasses under `Wild::Skillops::Error` (`ValidationError`,
  `NotFoundError`, `DuplicateSkillError`, `LifecycleError`,
  `RegistryCapacityError`, `VersionCapacityError`). The old gem's
  `ConfigurationFrozenError` is subsumed by `Wild::ConfigurationError`
  (Wild engine no longer freezes config — by design). The Configuration
  setter validation + freeze/frozen? machinery is NOT carried over;
  the 6 adversarial tests covering those features were deleted per
  Beck/F3 (no vanity tests of absent behavior).
- Export pair (`json_exporter` + `markdown_exporter`) retained in this PR
  to preserve test coverage during the structure move — the F6 wire-or-
  delete audit lives at `wild-rvv.8.3` and stays open.
- Closes `wild-rvv.8` base move. Children `wild-rvv.8.1` (F5 doc downgrade),
  `wild-rvv.8.2` (F10 BDUF cutback), `wild-rvv.8.3` (F6 exporter audit)
  remain open as Role 6 + Role 7 behavior follow-ups.

[Unreleased]: https://github.com/jeremylongshore/wild/compare/v0.0.0...HEAD
