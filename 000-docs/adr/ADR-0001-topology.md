# ADR-0001: Topology — one `wild` gem, ten namespaces

**Date:** 2026-05-29
**Status:** Accepted
**Deciders:** Jeremy Longshore (sole signer) after 7-seat adversarial thinker council (rev2)
**Supersedes:** the 10-gem `jeremylongshore/wild-*` topology

## Context

The original wild ecosystem shipped as 10 separate `jeremylongshore/wild-*` gems
(safe-introspection-mcp, admin-tools-mcp, capability-gate, session-telemetry,
transcript-pipeline, gap-miner, hook-ops, permission-analyzer, test-flake-forensics,
skillops-registry). A 7-seat adversarial thinker council (Fowler, Beck, Kleppmann,
Armstrong, Hickey, Karpathy, DHH) was convened to review the topology against the
findings from 21 per-repo reviews + an ecosystem review (2026-05-28).

Round 1 verdict: unanimous consensus on "NOT ten gems." Architect/founder defense
filed (10 points, see
`/home/jeremy/000-projects/wild/wild-rails-ai-ops/000-docs/012-AT-RBTL-jeremy-defense-of-multi-repo-2026-05-29.md`).
Round 2 rebuttals from all 7 seats. Final rev2 verdict at
`/home/jeremy/000-projects/wild/wild-rails-ai-ops/000-docs/013-AT-AUDT-thinker-council-verdict-rev2-2026-05-29.md`.

## Decision

**One `wild` gem with ten namespaces.** Mount as Rails engine. Ship
`rails g wild:install`. Adopt Topology A from the rev2 verdict.

The ten namespaces:

| Namespace | Origin (old gem) |
|---|---|
| `Wild::Introspection` | wild-rails-safe-introspection-mcp |
| `Wild::AdminTools` | wild-admin-tools-mcp |
| `Wild::CapabilityGate` | wild-capability-gate |
| `Wild::Telemetry::Collector` | wild-session-telemetry |
| `Wild::Telemetry::Pipeline` | wild-transcript-pipeline |
| `Wild::Telemetry::Analysis` | wild-gap-miner |
| `Wild::Hooks` | wild-hook-ops |
| `Wild::Analyzers::Permission` | wild-permission-analyzer |
| `Wild::Analyzers::TestFlakes` | wild-test-flake-forensics |
| `Wild::Skillops` | wild-skillops-registry (downgraded to internal per F5) |

## Vote tally (rev2)

| Position | Seats |
|---|---|
| HOLD one-gem | DHH, Fowler, Beck, Armstrong (4) |
| REFINE toward 2 gems (`wild` + `wild-mcp`) | Hickey (1) |
| REFINE toward 1+2 façades (`wild` + `wild-mcp-introspection` + `wild-mcp-admin`) | Karpathy (1) |
| REFINE inside-the-merge | Kleppmann (1) |
| CONCEDE outright | 0 |

Zero seats accepted the 10-gem topology. Three seats refined toward 2-3 gems
*only conditional on marketplace ambition being load-bearing today*. ADR-0002
captures the procedure to extract a namespace into its own gem when that
condition becomes true.

## Rationale

1. **Blast radius is a runtime property, not a packaging property.** Ten gems
   loaded into one Puma worker share heap, GVL, `ENV`, `Rails.cache`, connection
   pool. A bug in one namespace kills the worker regardless of gemspec count.
   Defense Point 2 fails on this physics.

2. **Gemspec boundary ≠ product boundary.** `Wild::Introspection` inside one gem
   encodes the same product boundary as a separate
   `wild-rails-safe-introspection-mcp` gem, with none of the version-skew cost.

3. **Enterprise trust prefers fewer moving parts.** Rails itself ships
   ActionPack/ActiveRecord/ActiveJob from one repo and is trusted enterprise-wide.
   One CHANGELOG + one SECURITY.md + one threat model > ten partially-overlapping
   versions of each.

4. **The coordination tax IS the cost.** Defense's own list of mitigations
   (Wild Repo Startup Standard, document consistency standard, ecosystem master
   blueprint, dependency map, per-repo Beads, 000-docs/ conventions,
   /repo-sweep discipline) is pure overhead the consolidation dissolves.

5. **Marketplace ambition (Point 10) is speculative infrastructure** at v0.1.0.
   No real marketplace consumer exists yet. Pay the extraction cost when the
   consumer appears (ADR-0002), not before.

## Earned carveouts from the defense

Defense Points 6 + 9 + partial 3, 5, 7, 8 earned **structural carveouts inside
the merged gem** without splitting gemspecs:

- **Point 6 (honest dependency direction):** Packwerk + RuboCop architectural lint
  + `# @api private` discipline + schemas-as-data enforce the goal inside one gem.
- **Point 7 (OSS adoption surface):** addressed by `bin/wild-mcp-introspection` +
  `bin/wild-mcp-admin` thin scripts. Adopters who only want introspection MCP
  use the bin script, not separate gem.
- **Point 9 (security review per capability):** addressed by per-namespace
  `THREAT_MODEL.md` and one root `threat_model.md`, not per-gemspec
  `SECURITY.md` files.
- **Point 3 (independent release cadence):** addressed by per-namespace
  CHANGELOG sections + per-namespace SemVer stamps + ADR-0002 extraction option.
- **Point 5 (Beads workflow):** per-namespace `bd` label query
  (`bd list --label <namespace>`) inside one root `.beads/`.
- **Point 8 (CI speed):** `bundle exec rake test:<namespace>` per-namespace
  scoped task; CI matrix on Ruby versions only, not on namespace × Ruby.

## Consequences

### Positive

- Single install: `bundle add wild && rails g wild:install`
- Five-minute adoption stopwatch test becomes achievable (DHH non-negotiable)
- One CI, one CHANGELOG, one SECURITY.md, one threat model
- Coordination tax (mitigations from defense list) dissolves
- F1 (configuration boilerplate broken across all gems) auto-resolves into one
  `Wild::Configuration` block
- Easier to extract a namespace later (ADR-0002 reversible) than to merge ten
  gems shipped to consumers

### Negative

- Larger gem footprint for adopters who only want one namespace
  (mitigated by `bin/` scripts for MCP-only consumers, and by `Wild.config.<ns>.enabled = false` defaults where applicable)
- Internal namespace coupling becomes possible without immediate alarm (mitigated
  by Packwerk in CI — a coupling violation fails the boundary job)
- Old `wild-*` consumers must migrate (mitigated by archive + redirect README
  pattern in Phase 4; their git history stays browsable)

### Neutral / acknowledged

- This decision does NOT resolve Hickey's data-shape critique (schema-as-data
  vs. ActiveModel tension remains; tracked inside the merged gem).
- This decision does NOT resolve Kleppmann's durability concerns; the rev2
  compromise is "fsync OR drop append-only audit log framing"; v0.1.0 picks
  the latter for `Wild::Telemetry::Collector`.
- This decision does NOT make Karpathy's agent-eval seams optional —
  `prompts/` directory + versioned tool descriptions + `bin/eval` stub ship
  in v1, per rev2.

## Preserved minority dissents

Per ISEDC pattern, minority positions do not vanish:

- Kleppmann + Hickey: `fsync` and durability are correctness, not theater.
- Karpathy: AI-native seams non-negotiable for the MCP namespaces.
- Armstrong: `Wild::Error` base hierarchy is non-optional (~30 LOC).
- Lamport: written invariants for skillops registry.
- Pike: channels-as-data-flow in hook-ops survives as `Wild::Hooks` refactor target.
- Cunningham: AAR + CHANGELOG discipline.
- Fowler's process indictment: the original 10-gem call was a
  ChiefArchitectAntiPattern; the multi-seat adversarial review is the repair.

## Provenance

- `/home/jeremy/000-projects/wild/wild-rails-ai-ops/000-docs/011-AT-AUDT-thinker-council-verdict-2026-05-29.md` (rev1)
- `/home/jeremy/000-projects/wild/wild-rails-ai-ops/000-docs/012-AT-RBTL-jeremy-defense-of-multi-repo-2026-05-29.md` (defense)
- `/home/jeremy/000-projects/wild/wild-rails-ai-ops/000-docs/010-AT-RBTL-*-2026-05-29.md` (7 rebuttal responses)
- `/home/jeremy/000-projects/wild/wild-rails-ai-ops/000-docs/013-AT-AUDT-thinker-council-verdict-rev2-2026-05-29.md` (rev2, this ADR's source of truth)
- `/home/jeremy/000-projects/wild/wild-rails-ai-ops/000-docs/010-AT-VRDT-dhh-2026-05-29.md` (DHH week-by-week migration plan)
