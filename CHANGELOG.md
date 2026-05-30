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

- _(pending: P1 code move from `wild-rails-safe-introspection-mcp`)_

### Wild::AdminTools

- _(pending: P1 code move from `wild-admin-tools-mcp` + DI-container removal)_

### Wild::CapabilityGate

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

- _(pending: P1 code move from `wild-session-telemetry`)_

### Wild::Telemetry::Pipeline

- _(pending: P1 code move from `wild-transcript-pipeline`)_

### Wild::Telemetry::Analysis

- _(pending: P1 code move from `wild-gap-miner`)_

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

- _(pending: P1 code move from `wild-permission-analyzer` + Fowler `detect_cycle` fix)_

### Wild::Analyzers::TestFlakes

- _(pending: P1 code move from `wild-test-flake-forensics` + Beck golden-corpus test)_

### Wild::Skillops

- _(pending: P1 code move from `wild-skillops-registry` as internal namespace — Lamport-flagged claims downgraded)_

[Unreleased]: https://github.com/jeremylongshore/wild/compare/v0.0.0...HEAD
