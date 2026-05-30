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

- _(pending: P1 code move from `wild-capability-gate` + F2 audit-blind fix)_

### Wild::Telemetry::Collector

- _(pending: P1 code move from `wild-session-telemetry`)_

### Wild::Telemetry::Pipeline

- _(pending: P1 code move from `wild-transcript-pipeline`)_

### Wild::Telemetry::Analysis

- _(pending: P1 code move from `wild-gap-miner`)_

### Wild::Hooks

- _(pending: P1 code move from `wild-hook-ops`)_

### Wild::Analyzers::Permission

- _(pending: P1 code move from `wild-permission-analyzer` + Fowler `detect_cycle` fix)_

### Wild::Analyzers::TestFlakes

- _(pending: P1 code move from `wild-test-flake-forensics` + Beck golden-corpus test)_

### Wild::Skillops

- _(pending: P1 code move from `wild-skillops-registry` as internal namespace — Lamport-flagged claims downgraded)_

[Unreleased]: https://github.com/jeremylongshore/wild/compare/v0.0.0...HEAD
