# Pre-move coupling survey — 10 old `wild-*` gems against ADR-0003

**Date:** 2026-05-30
**Author:** Jeremy Longshore (Role 4 PR-E)
**Status:** Final — gates Role 5 (gem mover)
**Provenance:**
- ADR-0001 (topology), ADR-0003 (namespace dependency graph)
- Council rev2 verdict (`/home/jeremy/000-projects/wild/wild-rails-ai-ops/000-docs/013-AT-AUDT-thinker-council-verdict-rev2-2026-05-29.md`)
- DHH per-repo merge table (`/home/jeremy/000-projects/wild/wild-rails-ai-ops/000-docs/010-AT-VRDT-dhh-2026-05-29.md`)
- Direct inspection of all 10 `wild-*/lib/` trees on 2026-05-30

## TL;DR

**The ten old gems have ZERO runtime cross-namespace constant coupling.** Every `WildXxx::*` constant reference inside any gem resolves inside that gem. There are no `require "wild_<other>"` statements across gems. Each gem ships as a runtime-independent unit.

That is the **good news**: ADR-0003's dependency graph will hold cleanly when Role 5 moves the code. There is no hidden coupling to refactor away first.

The **work that remains** for Role 5 is structural duplication — patterns that exist independently in multiple gems and must consolidate when they share a tier:
- 9 `Configuration` classes → already collapsed to one `Wild::Configuration` in PR-B (closes F1)
- 8 `errors.rb` files → already collapsed into the `Wild::Error` hierarchy in PR-C (closes MIN-Armstrong)
- 9 `version.rb` files → collapse to one when Role 5 moves code (F1 finish)
- 5 `export/markdown_exporter.rb` + 5 `export/json_exporter.rb` — F6 "half-published" candidates (council rev2)
- 2 `server/{tool_handler,server_factory}.rb` — MCP server pattern shared by introspection + admin_tools (Wild::Hooks Tier 1 substrate candidate)
- 4 `audit/` directories — audit pattern shared by introspection + admin_tools + capability_gate + hook-ops (Wild::Hooks Tier 1 substrate + F2 audit-emission)

The structural duplications are filed as beads under their parent namespace epics (see § "Beads filed" below). None of these violate ADR-0003 today; they will become real ADR-0003 dependency edges when Role 5 consolidates them.

---

## Method

For each of the 10 old gems, performed three checks against its `lib/` tree:

1. **Constant-reference scan** — `grep -rE "<other-gem-module>(::|[^A-Za-z_])"` for each of the 9 OTHER gems' top-level modules. Result: zero hits across all 10 gems.

2. **Require scan** — `grep -rE "require ['\"]wild[_-]"` to find any cross-gem `require` statement. Result: zero hits across all 10 gems.

3. **Filename overlap scan** — find paths that appear in more than one gem's `lib/` tree (excluding gem-name prefix). Result: 11 overlapping file paths covering version/configuration/errors (covered by PR-B + PR-C), exporters (F6 candidates), MCP server scaffolding (Wild::Hooks candidates), and audit patterns (Wild::Hooks + F2 candidates).

4. **Bonus** — `Gemfile` and `*.gemspec` inspection for cross-gem dependencies. Result: one `USE_LOCAL_CAPABILITY_GATE` env-toggle in `wild-admin-tools-mcp/Gemfile` (DHH's "Never ship" list item — eliminated by the consolidation anyway).

## Per-gem disposition vs. ADR-0003 tier

| Old gem | Target namespace | ADR-0003 tier | Constant coupling | Duplication to resolve |
|---|---|---|---|---|
| `wild-hook-ops` | `Wild::Hooks` | Tier 1 | None | Absorbs the MCP-server pattern + audit-logger pattern from admin_tools + introspection — Pike's "channels-as-data-flow" framing |
| `wild-session-telemetry` | `Wild::Telemetry::Collector` | Tier 1 | None | None (audit/recorder fragments belong in capability_gate per F2) |
| `wild-transcript-pipeline` | `Wild::Telemetry::Pipeline` | Tier 1 | None | None — wrong package boundary in old form per DHH; fine code, just moves |
| `wild-gap-miner` | `Wild::Telemetry::Analysis` | Tier 2 | None | Shares `export/{json,markdown}_exporter.rb` with permission-analyzer, skillops, test-flake-forensics, transcript-pipeline (F6 — most are unused per council) |
| `wild-permission-analyzer` | `Wild::Analyzers::Permission` | Tier 2 | None | Shares `export/` exporters (F6); the wildcard-matching code consolidates against the shared `lib/wild/schemas/wildcard_corpus.yml` landed in PR-D (F4) |
| `wild-test-flake-forensics` | `Wild::Analyzers::TestFlakes` | Tier 2 | None | Shares `export/` exporters (F6 — Beck named two of three as half-published); also `analyzers/coverage_analyzer.rb` shared with permission-analyzer |
| `wild-skillops-registry` | `Wild::Skillops` | Tier 2 | None | Shares `export/` exporters (F6); downgrade to internal per F5; default `enabled: false` already in `Wild::Configuration` (PR-B) |
| `wild-capability-gate` | `Wild::CapabilityGate` | Tier 3 | None | `audit/event.rb` consolidates to the `audit_event.yml` schema landed in PR-D (F2 anchor); `audit/json_lines_writer.rb` is the F2 emitter Role 6 wires |
| `wild-rails-safe-introspection-mcp` | `Wild::Introspection` | Tier 4 | One comment-only reference to `WildCapabilityGate.check` (line 40 of `identity/capability_gate.rb` — a docstring example, not code) | Shares `server/{tool_handler,server_factory}.rb` + `audit/{recorder,parameter_sanitizer,audit_logger,audit_record}.rb` with admin_tools (→ Wild::Hooks Tier 1 substrate candidates) |
| `wild-admin-tools-mcp` | `Wild::AdminTools` | Tier 4 | None (the `USE_LOCAL_CAPABILITY_GATE` env-toggle is dev-only Gemfile wiring, eliminated by consolidation) | Same shares as introspection — `server/` + `audit/` patterns → Wild::Hooks |

## Beads filed

For each meaningful duplication that Role 5 must resolve into a cross-tier dependency, one bead is filed under the affected namespace's epic. The beads link back to this survey doc for the full context.

| Bead | Epic | What |
|---|---|---|
| `wild-rvv.6.1` (P1) | `wild-rvv.6` (hooks) | Extract MCP server scaffold (`server/{tool_handler,server_factory}.rb`) from introspection + admin_tools into `Wild::Hooks::McpServer` Tier 1 substrate. Both Tier 4 namespaces then depend on Hooks for transport scaffolding |
| `wild-rvv.6.2` (P1) | `wild-rvv.6` (hooks) | Extract audit-logging pattern (`audit/{recorder,parameter_sanitizer}.rb`) from introspection + admin_tools + hook-ops into `Wild::Hooks::Audit` substrate. Capability-gate's `audit/event.rb` + `audit/json_lines_writer.rb` consume this substrate plus the F2 `audit_event.yml` schema from PR-D |
| `wild-rvv.7.2` (P1) | `wild-rvv.7` (analyzers) | Reconcile `analyzers/coverage_analyzer.rb` duplication between permission-analyzer + test-flake-forensics |
| `wild-rvv.4.4` (P1) | `wild-rvv.4` (capability_gate) | Migrate capability-gate's `audit/event.rb` data shape against the F2 `audit_event.yml` schema landed in PR-D; close the F2 design ↔ runtime loop |
| `wild-rvv.5.4` (P2) | `wild-rvv.5` (telemetry) | Audit gap-miner + permission-analyzer + skillops + test-flake-forensics + transcript-pipeline export pairs (`export/{json,markdown}_exporter.rb`) for F6 half-published surface — Beck flagged 2 of 3 test-flake exporters as unused; council mandates wire-or-delete |
| `wild-rvv.8.3` (P2) | `wild-rvv.8` (skillops) | Same F6 audit applied to skillops' export pair (default off per F5 — exporters may be removed entirely) |

## Wins vs. expectations

The build orchestration's Role 4 risk register named "hidden cross-namespace coupling not visible in audits" as the primary risk for Role 5 (`gates/gate-1-engine-shape.md`). The survey here demonstrates that risk does NOT materialize at the constant or `require` level. Role 5's work consolidates structural duplication (F1, F6, MIN-Armstrong, Wild::Hooks substrate emergence) rather than untangling runtime imports. That is materially less work than the worst case.

The structural-duplication beads above are the substrate Role 5 needs. Each one is targeted, ADR-0003-graph-valid (Hooks Tier 1 → consumed by Tiers 2/3/4 as documented), and links back to this survey for context.

## What this survey does NOT cover

- Behavioral coupling — the survey is static. Two gems may produce equivalent outputs from divergent code (e.g., both telemetry + transcript-pipeline normalize event shapes); these are F7/F8 council items already filed as `wild-rvv.5.1` + `wild-rvv.5.2`.
- Schema/data coupling — the wildcard corpus (F4) is already landed in PR-D and Role 6 wires the matchers per `wild-rvv.1.2.1`.
- Test-fixture coupling — out of scope; Role 7 owns consolidation.
- Gemfile.lock and dependency-graph audits — Bundler scope; not Packwerk's domain.

## Closing the Role 4 epic

This survey is the last Role 4 deliverable before Gate 1 final sign-off. PR-A through PR-F have landed the architectural contract Role 5 will execute against:

- **PR-A** (ADR-0003 + 11 package.yml + packwerk.yml) — boundary graph
- **PR-B** (typed `Wild::Configuration`) — F1 closed
- **PR-C** (`Wild::Error` hierarchy) — MIN-Armstrong closed
- **PR-D** (`lib/wild/schemas/`) — F4 design closed; runtime wiring pending Role 6
- **PR-E** (this survey) — Role 5 entry checklist
- **PR-F** (`CONTRIBUTING.md § Namespace-boundary discipline`) — contributor workflow

Role 5 (`ruby-pro`) claims `wild-rvv.2` through `wild-rvv.8` namespace epics and begins per-namespace code moves per `build-orchestration/roles/05-ruby-refactor-lead.md`.
