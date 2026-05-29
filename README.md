# wild

> Rails engine + generator: ten `Wild::*` namespaces (introspection, admin tools, capability gate, telemetry, hooks, analyzers, skillops) consolidated into one mountable gem. Council-blessed Topology A.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/jeremylongshore/wild/actions/workflows/ci.yml/badge.svg)](https://github.com/jeremylongshore/wild/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/jeremylongshore/wild/branch/main/graph/badge.svg)](https://codecov.io/gh/jeremylongshore/wild)
[![Release](https://img.shields.io/github/v/release/jeremylongshore/wild)](https://github.com/jeremylongshore/wild/releases)

## Overview

`wild` is a single Rails engine that lets a Rails app host safe, capability-gated, auditable AI agent operations. Ten cohesive namespaces ship inside one gem so a Rails team can install all of them — or use the ones they need — with a single `bundle add wild` and one `rails g wild:install`.

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

The ten original repos are archived with redirect READMEs pointing here. Their git histories remain readable for archaeology.

## Getting Started

### Installation

```ruby
# Gemfile
gem "wild"
```

```bash
bundle install
bin/rails g wild:install
bin/rails server
```

The install generator creates:
- `config/initializers/wild.rb` — single configuration block (no per-namespace classes)
- `config/wild/access_policy.yml` — introspection access policy
- `config/wild/capabilities.yml` — capability-gate rules
- Mounts `Wild::Engine` at `/wild` in `config/routes.rb`

### Five-minute adoption test

The DHH council verdict locked one non-negotiable: from a brand-new Rails 7.1 app, a developer must go from `bundle add wild` to a successful MCP `inspect_model_schema` call in **under five minutes by the stopwatch**. If it doesn't pass, v0.1.0 doesn't ship.

## Usage

### MCP servers

Two MCP servers ship as `bin/` scripts so non-Rails consumers can use them through plain MCP transports:

- `bin/wild-mcp-introspection` — wraps `Wild::Introspection`
- `bin/wild-mcp-admin` — wraps `Wild::AdminTools`

Each registers versioned tool descriptions under `prompts/` so prompt changes flow through code review (Karpathy seam, council-mandated).

### CLI analyzers

```bash
bundle exec wild analyzers:permission --model User
bundle exec wild analyzers:test-flakes --suite spec/
```

### Configuration

One nested-accessor `Wild.config` replaces the old ten `Configuration` classes:

```ruby
# config/initializers/wild.rb
Wild.configure do |config|
  config.introspection.access_policy_path = Rails.root.join("config/wild/access_policy.yml")
  config.admin_tools.cache_adapter        = Rails.cache    # defaulted
  config.admin_tools.job_adapter          = ActiveJob::Base # defaulted
  config.capability_gate.capabilities_path = Rails.root.join("config/wild/capabilities.yml")
  config.telemetry.collector.enabled       = true
end
```

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

Project documentation lives in [`000-docs/`](000-docs/):

| Doc | Purpose |
|-----|---------|
| [Business Case](000-docs/001-PP-BCASE-business-case.md) | Why consolidate; what consolidation buys |
| [PRD](000-docs/002-PP-PRD-product-requirements.md) | Requirements + the five-minute stopwatch test |
| [Architecture](000-docs/003-AT-ARCH-architecture.md) | Engine shape, namespace layout, boundary discipline |
| [User Journey](000-docs/004-PP-UJRN-user-journey.md) | Rails developer adoption flow |
| [Technical Spec](000-docs/005-AT-SPEC-technical-spec.md) | Stack, schemas, MCP transports |
| [Status](000-docs/006-OD-STAT-status.md) | Build progress against the 4-week plan |
| [ADR-0001](000-docs/adr/ADR-0001-topology.md) | One gem, ten namespaces — council-blessed |
| [ADR-0002](000-docs/adr/ADR-0002-namespace-extraction-policy.md) | When a namespace earns its own gemspec |

## Security

See [SECURITY.md](SECURITY.md) for vulnerability reporting.

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

## Author

**Jeremy Longshore** — [jeremylongshore](https://github.com/jeremylongshore)
