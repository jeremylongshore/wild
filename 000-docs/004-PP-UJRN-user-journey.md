# User Journey: wild

> Rails developer adoption flow + MCP consumer flow + security reviewer flow.

**Author:** Jeremy Longshore
**Date:** 2026-05-28
**Status:** Draft

## Journey 1: Rails developer adoption (DHH stopwatch test)

The flagship journey. Under five minutes wall-clock or v0.1.0 doesn't ship.

| Minute | Step | What happens |
|---|---|---|
| 0:00 | `rails new myapp --skip-bundle` | Fresh Rails 7.1 app |
| 0:15 | `cd myapp && bundle add wild` | One line in Gemfile, `bundle install` resolves |
| 1:00 | `bin/rails g wild:install` | Generator runs |
| 1:30 | Generator output: `config/initializers/wild.rb`, `config/wild/access_policy.yml`, `config/wild/capabilities.yml`, mounts `Wild::Engine` at `/wild` | Developer can see what was written |
| 2:00 | Developer skims `access_policy.yml` (allowed models) and `capabilities.yml` (what AI can do) | Defaults are safe — read-only introspection of `User`, no admin tools enabled |
| 2:30 | `bin/rails server` | App boots, engine mounts, no errors |
| 3:00 | Developer configures Claude Code MCP to point at `http://localhost:3000/wild/mcp/introspection` | One config line in Claude Code settings |
| 3:30 | Claude Code calls `inspect_model_schema(model: "User")` | MCP request reaches `Wild::Introspection`, passes through `Wild::CapabilityGate`, decision audit-emitted |
| 4:00 | Developer sees the model schema response | Success |
| 4:30 | Developer checks `log/development.log` and sees one structured audit event for the decision | F2 audit trail works |
| 5:00 | **Pass.** | |

If any step takes longer than its budget, the stopwatch fails. Role 8 (`dx-optimizer`) owns this journey.

## Journey 2: MCP consumer (non-Rails)

Someone wants to use `Wild::Introspection` as an MCP server WITHOUT mounting the engine. The bin-script path:

| Step | Command | Outcome |
|---|---|---|
| 1 | `gem install wild` | Gem installs |
| 2 | `wild-mcp-introspection --help` | Shows flags (`--access-policy`, `--allowed-models`) |
| 3 | `wild-mcp-introspection --access-policy ./policy.yml` | Server starts on stdio |
| 4 | Consumer's MCP client connects, calls tools | Each tool description is loaded from `prompts/`, response shape from `schemas/` |
| 5 | Consumer inspects the prompt files | Tool descriptions are versioned files; consumer can diff against `wild` releases |

## Journey 3: Security reviewer

| Step | Action | Outcome |
|---|---|---|
| 1 | Open https://github.com/jeremylongshore/wild | Lands on README; sees council-blessed Topology A statement up top |
| 2 | Read SECURITY.md | One disclosure path; per-namespace threat-surface notes; severity SLAs |
| 3 | Read 000-docs/003-AT-ARCH-architecture.md § Audit trail | F2 fix documented; structured audit event shape declared |
| 4 | Skim spec/wild/capability_gate/audit_liveness_spec.rb | Test proves audit emits on every decision path including `rescue` |
| 5 | Read 000-docs/adr/ADR-0001-topology.md and ADR-0002-namespace-extraction-policy.md | One-gem decision rationale + extraction procedure are explicit |
| 6 | Decide: approve / request changes / reject | One repo to review, not ten |

## Journey 4: Maintainer (Jeremy)

| Cadence | Action |
|---|---|
| Per PR | One CI run (RSpec + RuboCop + Packwerk + brakeman + bundler-audit + Codecov); one PR template; one review |
| Per release | One workflow_dispatch (Release); one CHANGELOG to edit; one version.rb to bump |
| Per security report | One SECURITY.md disclosure path; one triage |
| Per new namespace | New ADR amending ADR-0001 + Packwerk `package.yml` entry |

Coordination tax dissolves — that's the council-mandated win.

## What the journey does NOT include

- Choosing between ten gems before adoption (eliminated by Topology A)
- Resolving version skew across `wild-*` Gemfile entries (eliminated)
- Reading ten partial SECURITY.md files (eliminated)
- Wiring nine DI adapter classes (eliminated by defaulted adapters in `Wild::AdminTools`)
