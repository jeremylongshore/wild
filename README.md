# wild

> Rails engine + generator: ten `Wild::*` namespaces (introspection, admin tools, capability gate, telemetry, hooks, analyzers, skillops) consolidated into one mountable gem. Council-blessed Topology A.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/jeremylongshore/wild/actions/workflows/ci.yml/badge.svg)](https://github.com/jeremylongshore/wild/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/jeremylongshore/wild/branch/main/graph/badge.svg)](https://codecov.io/gh/jeremylongshore/wild)
[![Release](https://img.shields.io/github/v/release/jeremylongshore/wild)](https://github.com/jeremylongshore/wild/releases)

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/U5S225PTME)

> **Status: 0.0.1 pre-release (not on RubyGems; no tags).** The consolidation build paused
> 2026-06-02 mid-phase P1 and a strategic review wave opened 2026-08-25
> (`000-docs/009-PP-PLAN-strategic-review-and-fix-wave-2026-08-25.md`).
>
> **Works today:** the library (`require "wild"`, all ten `Wild::*` namespaces), `Wild.configure`,
> the per-namespace rake test tasks, the full RSpec suite (3083+ examples) and RuboCop in CI.
>
> **Not yet:** `rails g wild:install` (stub), the two MCP server binaries (stubs that exit 1;
> not declared as gem executables), `prompts/` (does not exist), the five-minute stopwatch test,
> a v0.1.0 release, and the archive of the ten original `wild-*` repos (still un-archived).
> v0.1.0 cuts only when the stopwatch gate passes (Role 11 of the build plan).

## Overview

`wild` is a single Rails engine that lets a Rails app host safe, capability-gated, auditable AI agent operations. Ten cohesive namespaces ship inside one gem so a Rails team can install all of them — or use the ones they need — with a single `bundle add wild` and one `rails g wild:install` (the generator is the P2 deliverable; see the status block above).

The namespaces:

| Namespace | Responsibility |
|---|---|
| `Wild::Introspection` | Safe runtime introspection (model schemas, routes, config) over MCP |
| `Wild::AdminTools` | Privileged admin operations over MCP, gated by capability rules |
| `Wild::CapabilityGate` | Per-capability policy evaluation, decision logging, audit trail |
| `Wild::Telemetry::Collector` | Privacy-aware session/event ingestion |
| `Wild::Telemetry::Pipeline` | Normalization, sequence numbering, dispatch |
| `Wild::Telemetry::Analysis` | Gap detection from collected telemetry |
| `Wild::Hooks` | Hook lifecycle + concerns shared across namespaces |
| `Wild::Analyzers::Permission` | Permission model analyzer (CLI + library) |
| `Wild::Analyzers::TestFlakes` | Test flake forensics (CLI + library) |
| `Wild::Skillops` | Skill/capability registry (internal — earn separate gem when external consumer appears) |

## Origin

This repo consolidates ten previously-separate gems (`jeremylongshore/wild-*`) into one Rails engine after a seven-seat adversarial thinker council unanimously rejected the ten-gem topology. The canonical decision record is [`000-docs/adr/ADR-0001-topology.md`](000-docs/adr/ADR-0001-topology.md). The decision to defer separate-gem extraction until a real external consumer with divergent cadence appears is [`000-docs/adr/ADR-0002-namespace-extraction-policy.md`](000-docs/adr/ADR-0002-namespace-extraction-policy.md).

The ten original repos are **not yet archived**; per ADR-0001 they get archived with redirect READMEs pointing here at the end of the build (phase P4). Their git histories remain readable for archaeology.

## Getting Started

### Installation

```ruby
# Gemfile
gem "wild"
```

```bash
bundle install
bin/rails g wild:install   # PLANNED (P2): today this generator is a stub
bin/rails server
```

The install generator will create:
- `config/initializers/wild.rb` — single configuration block (no per-namespace classes)
- `config/wild/access_policy.yml` — introspection access policy
- `config/wild/capabilities.yml` — capability-gate rules
- Mounts `Wild::Engine` at `/wild` in `config/routes.rb`

### Five-minute adoption test

The DHH council verdict locked one non-negotiable: from a brand-new Rails 7.1 app, a developer must go from `bundle add wild` to a successful MCP `inspect_model_schema` call in **under five minutes by the stopwatch**. If it doesn't pass, v0.1.0 doesn't ship.

## Usage

### MCP servers (planned, P2)

Two MCP servers are planned to ship as `bin/` scripts so non-Rails consumers can use them through plain MCP transports:

- `bin/wild-mcp-introspection` — wraps `Wild::Introspection`
- `bin/wild-mcp-admin` — wraps `Wild::AdminTools`

Today both files are stubs that print a pending notice and `exit 1`; they are deliberately not declared as gem executables until they work. The in-process server factories (`Wild::Introspection::Server`, `Wild::AdminTools::Server`) exist and are covered by specs. Versioned tool descriptions under `prompts/` (the Karpathy seam) are also planned, not shipped.

### Analyzers

`Wild::Analyzers::Permission` and `Wild::Analyzers::TestFlakes` are library APIs (see their specs under `spec/wild/analyzers/`). There is no `wild` command-line executable yet.

### Configuration

One nested-accessor `Wild.config` replaces the old ten `Configuration` classes. `Wild::Engine`'s
`config.after_initialize` hook bridges it into the two namespaces (`Wild::AdminTools`,
`Wild::Introspection`) that still read from their own pre-consolidation configuration object at
runtime:

```ruby
# config/initializers/wild.rb
Wild.configure do |config|
  config.introspection.access_policy_path    = Rails.root.join("config/wild/access_policy.yml")
  config.introspection.blocked_resources_path = Rails.root.join("config/wild/blocked_resources.yml")

  # cache_adapter/job_adapter/flag_adapter default to :default; the engine
  # resolves that to Rails.cache / Sidekiq / Flipper when the backend gem is
  # loaded, or raises Wild::ConfigurationError at boot naming the setting.
  # Only Sidekiq is a shipped job_adapter backend (no ActiveJob::Base
  # adapter exists: ActiveJob has no generic queue-introspection API); set
  # job_adapter/flag_adapter explicitly if you're not on Sidekiq/Flipper.
  config.admin_tools.cache_adapter         = Rails.cache

  config.capability_gate.capabilities_path = Rails.root.join("config/wild/capabilities.yml")
  config.telemetry.collector.enabled       = true
end
```

Both `access_policy_path` and `blocked_resources_path` are required together: the introspection
policy loader raises if only one is set. See `Wild::AdminTools.bridge_configuration!` and
`Wild::Introspection.bridge_configuration!` (`lib/wild/admin_tools.rb`, `lib/wild/introspection.rb`)
for the full bridging contract.

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
bundle exec packwerk check
```

Per-namespace test tasks:

```bash
bundle exec rake test:introspection
bundle exec rake test:admin_tools
bundle exec rake test:capability_gate
bundle exec rake test:telemetry
bundle exec rake test:hooks
bundle exec rake test:analyzers
bundle exec rake test:skillops
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full setup.

## Documentation

Project documentation lives in [`000-docs/`](000-docs/); the site-map is
[`000-docs/000-INDEX.md`](000-docs/000-INDEX.md).

| Doc | Purpose |
|-----|---------|
| [Business Case](000-docs/001-PP-BCASE-business-case.md) | Why consolidate; what consolidation buys |
| [PRD](000-docs/002-PP-PRD-product-requirements.md) | Requirements + the five-minute stopwatch test |
| [Architecture](000-docs/003-AT-ARCH-architecture.md) | Engine shape, namespace layout, boundary discipline |
| [User Journey](000-docs/004-PP-UJRN-user-journey.md) | Rails developer adoption flow |
| [Technical Spec](000-docs/005-AT-SPEC-technical-spec.md) | Stack, schemas, MCP transports |
| [Status](000-docs/006-OD-STAT-status.md) | Build progress against the 11-role plan |
| [CodeQL strategy](000-docs/007-AT-STND-codeql-strategy.md) | `security-extended` on ruby + actions |
| [Pre-move coupling survey](000-docs/008-AT-AUDT-pre-move-coupling-survey.md) | Static coupling audit of the ten old gems |
| [Review-wave plan](000-docs/009-PP-PLAN-strategic-review-and-fix-wave-2026-08-25.md) | Plan of record for the 2026-08-25 review interlude |
| [ADR-0001](000-docs/adr/ADR-0001-topology.md) | One gem, ten namespaces — council-blessed |
| [ADR-0002](000-docs/adr/ADR-0002-namespace-extraction-policy.md) | When a namespace earns its own gemspec |
| [ADR-0003](000-docs/adr/ADR-0003-namespace-dependency-graph.md) | Four-tier namespace dependency DAG (Packwerk) |

## Security

See [SECURITY.md](SECURITY.md) for vulnerability reporting.

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

## Author

**Jeremy Longshore** — [jeremylongshore](https://github.com/jeremylongshore)
