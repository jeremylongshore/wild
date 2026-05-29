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
are not packwerk-tracked; they form the engine substrate that every
namespace inherits.

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

Packwerk's `enforce_privacy: true` enforces the marker at AST level.
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
