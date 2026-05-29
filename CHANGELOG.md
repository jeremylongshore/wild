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

- Initial project setup with full governance (README, LICENSE, CODE_OF_CONDUCT, CONTRIBUTING, SECURITY, SUPPORT, CLAUDE.md, AGENTS.md, EditorConfig, gitattributes)
- CI workflow (Ruby 3.2 + 3.3 + 3.4 matrix; RSpec, RuboCop, Packwerk, brakeman, bundler-audit; Codecov upload)
- Release workflow (workflow_dispatch only — no auto-release on push; v0.1.0 ships at end of the 4-week consolidation build)
- Dependabot for bundler + GitHub Actions
- Issue templates (bug, feature) + PR template
- CODEOWNERS, FUNDING
- Ruby gem skeleton: `wild.gemspec`, Gemfile, Rakefile, `bin/console`, `bin/setup`
- Engine skeleton: `lib/wild.rb`, `lib/wild/engine.rb`, `lib/wild/version.rb`, `lib/wild/error.rb`, `lib/wild/configuration.rb`
- Namespace directory placeholders under `lib/wild/`
- ADR-0001 (topology — one gem, ten namespaces)
- ADR-0002 (namespace extraction policy)
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
