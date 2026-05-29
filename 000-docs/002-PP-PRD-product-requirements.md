# Product Requirements: wild

> Rails engine + generator: ten `Wild::*` namespaces consolidated into one mountable gem.

**Author:** Jeremy Longshore
**Date:** 2026-05-28
**Status:** Draft (v0.1.0 scope)

## Vision

A Rails app that wants to host safe AI-agent operations runs `bundle add wild && rails g wild:install`, edits two YAML files, mounts the engine, and gets all ten `Wild::*` namespaces wired correctly by default — including MCP transports for introspection and admin tools, a capability gate enforcing per-action policy, audit-emission on every decision, and telemetry collection ready to flow.

## Goals for v0.1.0

1. **One mountable Rails engine** — `Wild::Engine` with `isolate_namespace Wild`
2. **One install generator** — `rails g wild:install` produces working defaults
3. **One configuration block** — `Wild.config.<namespace>.<setting>` nested accessors
4. **Two MCP servers as `bin/` scripts** — `bin/wild-mcp-introspection`, `bin/wild-mcp-admin`
5. **One audit trail** — every capability-gate decision (including `rescue` paths) emits a structured audit event
6. **The five-minute stopwatch test passes** — DHH-mandated v0.1.0 gate

## Non-goals for v0.1.0

These are deferred per council rev2 verdict:

- Kleppmann's fsync / segment files / consumer offsets in telemetry (defer until distributed consumer appears)
- Karpathy's 30-prompt agent-eval CI gate (v1 ships first; seams ship as `prompts/` directory and `bin/eval` stub)
- Lamport's TLA+ skillops formalization (premature)
- Armstrong's supervision tree / FallbackWriter (premature — supervisor is Puma at gem scale)
- Marketplace registration (no real consumer yet; ADR-0002 makes future extraction reversible)
- Per-namespace separate gemspecs

## Personas

### Rails Tech Lead (primary)

Adopts `wild` because their app needs to expose safe operations to AI agents. Wants:

- One install command
- One configuration file
- One CHANGELOG to track
- One SECURITY.md to review

Success: passes the five-minute stopwatch test.

### MCP Consumer (non-Rails)

Uses `bin/wild-mcp-introspection` or `bin/wild-mcp-admin` directly without mounting the engine. Wants:

- Tool descriptions versioned and reviewable (`prompts/`)
- Predictable response schemas (`schemas/`)
- Discovery tools (`list_allowed_models`)

### Security Reviewer

Auditing the gem before adoption. Wants:

- One SECURITY.md
- One threat model
- Per-namespace threat-surface notes
- Audit-trail completeness (no rescue path silently swallows)

### Maintainer (Jeremy)

Wants:

- One CI to maintain
- One sectioned CHANGELOG
- Per-namespace `rake test:<namespace>` so changes test fast
- Packwerk enforcing namespace boundaries automatically

## Functional requirements

| # | Requirement | Acceptance |
|---|---|---|
| FR-1 | `bundle add wild` resolves and installs cleanly on Ruby 3.2/3.3/3.4 + Rails 7.1+ | CI matrix green |
| FR-2 | `rails g wild:install` creates initializer, two YAML config files, mounts engine in routes | Generator spec passes |
| FR-3 | `Wild::Introspection` exposes safe model schema introspection through MCP | MCP spec passes + dummy-app integration test |
| FR-4 | `Wild::AdminTools` exposes admin operations through MCP, all gated by `Wild::CapabilityGate` | MCP spec passes + audit-emission test |
| FR-5 | `Wild::CapabilityGate` emits a structured audit event on every decision including `rescue` paths | Audit-liveness test (Armstrong F2) |
| FR-6 | `Wild::Telemetry::{Collector,Pipeline,Analysis}` ingests, normalizes, and analyzes session events | Pipeline integration test |
| FR-7 | `Wild::Analyzers::Permission` correctly detects cycles (no false positives) | Fowler `detect_cycle` regression test |
| FR-8 | `Wild::Analyzers::TestFlakes` classifies flakes against a golden corpus | Beck golden-corpus test |
| FR-9 | Stopwatch test passes | Dry-run at end of P2, full run in P4, under 5 minutes wall-clock |

## Non-functional requirements

| # | Requirement | Acceptance |
|---|---|---|
| NFR-1 | Coverage threshold ≥ 85% across all namespaces | Codecov enforces; CI fails on regression |
| NFR-2 | RuboCop clean | CI lint job |
| NFR-3 | Packwerk boundaries clean | CI boundary job |
| NFR-4 | Brakeman clean | CI security job |
| NFR-5 | bundler-audit clean | CI security job |
| NFR-6 | Per-namespace test runs in < 30 s on a stock GitHub Actions runner | `rake test:<namespace>` timing assertion |
| NFR-7 | MCP tool descriptions versioned under `prompts/<tool>.md` | Karpathy seam — diff visible in code review |

## The Five-Minute Stopwatch Test (v0.1.0 gate)

Per DHH council verdict:

> Brand-new Rails 7.1 app, blank `Gemfile`, no prior knowledge of `wild`. The candidate Rails developer reads the README and runs:
>
> ```
> bundle add wild
> bin/rails g wild:install
> # inspect config/initializers/wild.rb, config/wild/access_policy.yml
> bin/rails server
> # point Claude Code MCP at http://localhost:3000/wild/mcp
> ```
>
> Under five minutes from `bundle add` to a successful `inspect_model_schema` MCP call against a dev model — or it doesn't ship.

The stopwatch test is implemented by Role 8 (`dx-optimizer`) and validated by Role 11 (`deployment-engineer`) as the final gate before v0.1.0 cuts.

## The 13 council-blessed v1.1 fixes

The fixes land before v0.1.0. Tracked under `label:thinker-council`:

| Code | Severity | Summary | Lead namespace |
|---|---|---|---|
| F1 | P0 | Configuration boilerplate / freeze-reset broken across all gems → one `Wild.config` | all |
| F2 | P0 | Audit-blind error paths leave irrecoverable silence | capability_gate |
| F3 | P0 | Tests confirm code runs, not that judgment is correct | all (test consolidator) |
| F4 | P0 | Cross-namespace contract drift undefended → schemas-as-data | engine + boundaries |
| F5 | P0 | Skillops-registry claims its code can't back up | skillops |
| F6 | P1 | Half-published / dead API surface | capability_gate, telemetry, test_flakes |
| F7 | P1 | Boundary normalization missing wherever data crosses namespaces | telemetry, introspection |
| F8 | P1 | Data shape complects identity, value, and time | telemetry/analysis |
| F9 | P1 | No Rails generator anywhere; adoption story broken | engine |
| F10 | P1 | BDUF docs before consumers | repo-wide |
| MIN-Kleppmann | P1 | fsync OR drop append-only audit log framing | telemetry/collector |
| MIN-Karpathy | P1 | AI-native seams ship as v1 — `prompts/`, versioned tool descriptions, `bin/eval` stub | introspection, admin_tools |
| MIN-Armstrong | P1 | `Wild::Error` base hierarchy | engine |

Three additional preserved minority dissents (Lamport invariants, Pike channels, Cunningham AAR) are tracked but not council-rated as v1.1 blockers — they remain reviewable inputs through the build.
