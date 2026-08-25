# ADR-0003: Namespace dependency graph — who may depend on whom

**Date:** 2026-05-30
**Status:** Accepted
**Deciders:** Jeremy Longshore after Role 4 (engine architect) design
**Relates to:** ADR-0001 (topology), ADR-0002 (namespace extraction policy)

## Context

ADR-0001 locked one `wild` gem with ten `Wild::*` namespaces.
ADR-0002 governs when a namespace earns its own gemspec.

Neither ADR specifies **which namespaces may depend on which other
namespaces inside the merged gem.** Without an explicit dependency
graph, every namespace can in principle reach into every other
namespace's internals, recreating the hidden coupling problem the
council named in defense Point 6 (honest dependency direction).

The mechanism the council blessed for enforcing this is Packwerk
per-namespace `package.yml`. This ADR declares the contract Packwerk
enforces.

## Decision

Ten namespaces sit in a four-tier directed acyclic graph:

```
┌─ Tier 4 — transport surface (consumes everything below) ────────────────┐
│                                                                         │
│   Wild::Introspection      Wild::AdminTools                             │
│   (lib/wild/introspection) (lib/wild/admin_tools)                       │
│        ▲                          ▲                                     │
└────────┼──────────────────────────┼──────────────────────────────────────┘
         │                          │
┌────────┴──────────────────────────┴─────────────────────────────────────┐
│ Tier 3 — capability gate (gates Tier 4 admin calls)                     │
│                                                                         │
│   Wild::CapabilityGate                                                  │
│   (lib/wild/capability_gate)                                            │
│        ▲                                                                │
└────────┼────────────────────────────────────────────────────────────────┘
         │
┌────────┴────────────────────────────────────────────────────────────────┐
│ Tier 2 — analyzers + telemetry analysis (consume normalized data)       │
│                                                                         │
│   Wild::Analyzers::Permission   Wild::Analyzers::TestFlakes             │
│   Wild::Telemetry::Analysis     Wild::Skillops                          │
│        ▲                                                                │
└────────┼────────────────────────────────────────────────────────────────┘
         │
┌────────┴────────────────────────────────────────────────────────────────┐
│ Tier 1 — telemetry ingest + shared hooks (no internal deps)             │
│                                                                         │
│   Wild::Telemetry::Collector    Wild::Telemetry::Pipeline               │
│   Wild::Hooks                                                           │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Allowed dependencies (the Packwerk contract)

| Namespace | May depend on |
|---|---|
| `Wild::Hooks` | (no `Wild::` namespaces — shared concerns substrate) |
| `Wild::Telemetry::Collector` | `Wild::Hooks` |
| `Wild::Telemetry::Pipeline` | `Wild::Hooks`, `Wild::Telemetry::Collector` |
| `Wild::Telemetry::Analysis` | `Wild::Hooks`, `Wild::Telemetry::Pipeline` |
| `Wild::Analyzers::Permission` | `Wild::Hooks` |
| `Wild::Analyzers::TestFlakes` | `Wild::Hooks`, `Wild::Telemetry::Analysis` |
| `Wild::Skillops` | `Wild::Hooks` |
| `Wild::CapabilityGate` | `Wild::Hooks`, `Wild::Analyzers::Permission` |
| `Wild::Introspection` | `Wild::Hooks`, `Wild::CapabilityGate` |
| `Wild::AdminTools` | `Wild::Hooks`, `Wild::CapabilityGate` |

Engine-level files (`lib/wild.rb`, `lib/wild/engine.rb`,
`lib/wild/configuration.rb`, `lib/wild/error.rb`, `lib/wild/version.rb`)
form the engine substrate that every namespace inherits via its `"."`
dependency on the root package (see the 2026-08-25 amendment below: as
of this fix they ARE packwerk-tracked, resolved to the root package).

### Forbidden patterns

1. **Upward dependency.** A lower tier may NOT depend on a higher
   tier. Example forbidden: `Wild::Telemetry::Collector` depends on
   `Wild::CapabilityGate` (collector is Tier 1, gate is Tier 3).
2. **Sideways dependency between admin and introspection.** They are
   both Tier 4 and must remain independent — both go through Tier 3
   (`Wild::CapabilityGate`) but never reach into each other.
3. **Direct `Wild::Telemetry::Collector` ↔ `Wild::Telemetry::Analysis`
   coupling.** Analysis only sees Pipeline-normalized events (F7 fix);
   reaching into Collector bypasses the normalization seam.
4. **Cycles of any kind.** Packwerk's `enforce_dependencies: true`
   detects them.

### Rationale

- **`Wild::Hooks` as Tier 1 shared substrate.** Pike's per-repo review
  surfaced `Wild::Hooks` as "channels-as-data-flow" — the place where
  every namespace borrows shared concerns. Sits at the bottom so
  everyone can use it; depends on no other `Wild::*` namespace.
- **Telemetry pipeline layered top-to-bottom.** Kleppmann's normalize
  step (F7) is what separates ingest (Collector) from analysis. Each
  tier consumes only the layer below.
- **CapabilityGate as Tier 3.** Has to come between the data tier
  (Analyzers) and the transport tier (Introspection / AdminTools)
  because every admin call passes through it (F2). Its dependency on
  `Wild::Analyzers::Permission` is the policy-evaluation engine the
  gate delegates to.
- **Skillops as Tier 2.** Per F5, downgraded to internal namespace;
  it's a reference data store consumed by higher tiers via explicit
  query, never injecting itself.
- **Introspection + AdminTools at Tier 4, independent siblings.** Both
  speak MCP transport; both gate through `Wild::CapabilityGate`; neither
  knows about the other. A consumer using only Introspection
  (`bin/wild-mcp-introspection`) never loads AdminTools code.

### Public-API surface (`# @api private` enforcement)

Each namespace's `lib/wild/<ns>/` directory has an implicit two-tier
shape:

| Tier | Marker | Visible to |
|---|---|---|
| Public | None | Other namespaces (per the table above), engine, consumers |
| Private | `# @api private` YARD tag on the constant or method | Only that namespace's own files |

`# @api private` is convention only, enforced by code review, not by
Packwerk (see the 2026-08-25 amendment below: `enforce_privacy` needs
the `packwerk-extensions` gem, which this repo does not depend on).
A symbol without `# @api private` is callable from any namespace that
declares this namespace as a dependency.

A NEW public symbol (introduced by removing `# @api private` OR a
brand-new public class/method) requires:
1. CHANGELOG entry under that namespace's section
2. RSpec describing the public contract
3. PR review by the namespace's CODEOWNERS

These rules are documented in CONTRIBUTING.md (PR-F of Role 4).

## Consequences

### Positive

- Coupling is provably bounded by the Packwerk graph.
- A new contributor can see "who may import whom" at a glance.
- Hidden cross-namespace coupling fails CI (Packwerk's
  `enforce_dependencies: true`).
- Sets the substrate Role 5 needs before code moves: each old gem's
  `lib/` tree gets moved into a namespace dir, and that namespace's
  package.yml declares what it may depend on. Cross-namespace imports
  in the old code that violate this graph become beads to resolve
  before the move completes.

### Negative

- Adding a new edge to the graph requires an ADR amendment. This is
  intentional friction — the council wanted boundary changes to be
  decisions, not drift.
- The Tier 1 shared substrate (`Wild::Hooks`) can grow into a
  god-namespace if not policed. Mitigation: per-namespace
  `THREAT_MODEL.md` calls out what does NOT belong in Hooks.

### Neutral / acknowledged

- This ADR does NOT prescribe internal module structure inside each
  namespace — that's per-namespace design. Packwerk only enforces the
  inter-namespace contract.
- The graph is the v0.1.0 baseline. ADR-0002 governs extraction; an
  extracted namespace's gemspec inherits whatever dependencies its
  package.yml declared.

## Provenance

- ADR-0001 (topology decision)
- ADR-0002 (namespace extraction policy)
- 000-docs/003-AT-ARCH-architecture.md § Boundary discipline
- Council rev2 verdict §F4 (cross-namespace contract drift) +
  §F7 (boundary normalization) — both informed the Tier 1 → Tier 4 layering
- DHH per-repo merge table — confirms each namespace's archetype
- Pike review of `wild-hook-ops` — informed `Wild::Hooks` as Tier 1
- Kleppmann/Hickey on telemetry layering — informed Collector → Pipeline → Analysis chain

## Amendment (2026-08-25, review wave f-x2-2 / f-x2-5)

Two factual corrections to the sections above, and one documented gap, from
the paired `/code-review` verifier on PR #72. This is a truth-sync, not a
topology change: no edge in the "Allowed dependencies" table above moved.

1. **The engine substrate IS packwerk-tracked now.** "Engine-level files
   ... are not packwerk-tracked" (above) was accurate when written but is
   now stale: `packwerk.yml` no longer excludes `lib/wild.rb`,
   `lib/wild/engine.rb`, `lib/wild/configuration.rb`, `lib/wild/error.rb`,
   or `lib/wild/version.rb`. They resolve to the root package
   (`package.yml`, `dependencies: []`), and every namespace's `"."`
   dependency on that root package is what makes referencing
   `Wild::Error`, `Wild.config`, `Wild::Configuration`, and `Wild::Engine`
   a checked, legal edge instead of untracked code Packwerk never saw.
   Before this fix, the exclusion made the `"."` dependency dead
   configuration: nothing in those five files was in Packwerk's constant
   map, so nothing could ever have been flagged for referencing them, and
   `packwerk check` staying at 0 offenses was not evidence the edge worked.

2. **`enforce_privacy: true` is NOT enforced.** "Packwerk's
   `enforce_privacy: true` enforces the marker at AST level" (above) was
   never true for this repo: that key belongs to the separate
   `packwerk-extensions` gem, which `wild` does not depend on. Every
   `package.yml` carried `enforce_privacy: true` regardless, which
   `bundle exec packwerk validate` rejects outright as an unknown key,
   meaning `packwerk validate` was never run in CI before this fix (only
   `packwerk check`, which does not validate manifest schema). The key has
   been removed from all eleven `package.yml` files. `# @api private` is
   convention and code-review discipline today, not a CI-enforced
   boundary. Adopting `packwerk-extensions` to make it real is a
   follow-up, not done here (CHANGELOG `### Repo`).

3. **Known enforcement hole: the ten namespace entry files.** Each
   namespace's `lib/wild/<ns>.rb` (module definition + requires + a
   handful of module-level factory/config methods, e.g.
   `Wild::Skillops.build`) sits in `lib/wild/`, not inside its own
   namespace subdirectory, so Packwerk's directory-based resolution
   assigns it to the root package. These ten files remain excluded from
   `packwerk.yml` (same shape the five engine-substrate files used to
   have). Effect: a boundary violation reachable only through one of
   these module-level entry points (`Wild::Skillops`, `Wild::AdminTools`,
   `Wild::Introspection.configuration`,
   `Wild::Analyzers::Permission::LoadError`, and so on) is invisible to
   `packwerk check` and will not block CI. A cheap fix was investigated
   (make each entry file a thin `require`-only shim, moving module-level
   API into a namespace-owned subfile such as a `Facade` class) and found
   mechanical for a single small namespace but not something to carry
   across all nine remaining entry files (609 combined lines) and their
   call sites in one pass; tracked as a follow-up (CHANGELOG `### Repo`).
   Until closed, this is the graph's one real gap: everything in the
   "Allowed dependencies" table is enforced except reads that go through
   a namespace's own entry-file module method.
