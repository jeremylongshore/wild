# Business Case: wild

> Rails engine + generator: ten `Wild::*` namespaces consolidated into one mountable gem.

**Author:** Jeremy Longshore
**Date:** 2026-05-28
**Status:** Approved (council rev2, 2026-05-29)

## Problem Statement

Rails teams that want to give AI agents safe, capability-gated, auditable access to their running app currently have to:

1. Pick from ten loosely-coordinated `jeremylongshore/wild-*` gems
2. Pin versions across all ten in their Gemfile
3. Wire ten `Configuration` singletons, each with its own broken `freeze!`/`reset!` dance
4. Connect MCP transports by hand
5. Stand up their own audit, telemetry, capability-gate stories

The ten-gem topology forces every consumer to integrate ten things. Council rev2 named this **the coordination tax**: the *Wild Repo Startup Standard*, the document consistency standard, the ecosystem master blueprint, the dependency map, the per-repo Beads, the 000-docs/ conventions, the /repo-sweep discipline — all mitigations for a packaging shape the code never earned.

`wild` consolidates the ten gems into one Rails engine. A Rails team installs once, mounts the engine, runs one generator, and gets all ten namespaces wired correctly by default.

## Target Customer

| Segment | Role | Pain Level |
|---------|------|-----------|
| Rails product teams adopting AI agents | Tech lead | High — they want `bundle add` not "evaluate ten gems" |
| MCP server consumers (non-Rails) | Solutions engineer | Medium — they want one transport entry, not ten |
| Auditors / security reviewers | Compliance lead | High — one SECURITY.md beats ten partially-overlapping versions |
| Maintainer (Jeremy) | Architect | High — coordination tax dissolves; one CHANGELOG, one CI, one threat model |

## Market Size

| Metric | Value |
|--------|-------|
| TAM | Every Rails-7.1+ app considering AI-agent integration |
| SAM | Teams using Claude Code / MCP-compatible agents who need an in-Rails policy gate |
| SOM (Year 1) | Inbound from the existing 10-gem audience plus partner-engagement consumers |

## ROI Calculation

| Scenario | Without wild | With wild | Savings |
|----------|--------------|-----------|---------|
| Adoption time | Afternoon to evaluate + wire 10 gems | Under 5 minutes (DHH stopwatch) | ~95% of adoption time |
| Version pinning | 10 gems, version-skew risk | 1 gem, internal SemVer per namespace | Eliminates the entire skew class |
| Configuration surface | 10 broken singletons | 1 `Wild.config` nested-accessor block | One file edited, not ten |
| Audit reviewer cost | 10 partial SECURITY.md | 1 cohesive SECURITY.md + per-namespace threat surface | Single review pass |
| Maintainer overhead | 10 CIs, 10 CHANGELOGs, 10 versions | 1 CI, 1 sectioned CHANGELOG, internal stamps | Council-mandated dissolution |

## Competitive Positioning

| Feature | wild | Manual stitching of 10 gems | Generic MCP libs |
|---------|------|------------------------------|------------------|
| One install (`bundle add wild`) | Yes | No | No |
| Rails generator | Yes (`rails g wild:install`) | No | No |
| Capability gate built in | Yes | Requires `wild-capability-gate` + wiring | Out of scope |
| Audit trail | Yes (F2-corrected) | Maybe (depends which gems chosen) | No |
| MCP servers as `bin/` scripts | Yes (`bin/wild-mcp-introspection`, `bin/wild-mcp-admin`) | No | Partial |
| One CHANGELOG / SECURITY / threat-model | Yes | No (ten partial documents) | No |

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Coupled namespaces leak across boundaries | Medium | High | Packwerk lint; `# @api private` discipline; ADR-0002 extraction policy |
| Stopwatch test fails at P4 | Medium | High (blocks v0.1.0) | Dry stopwatch test at end of P2 per build plan |
| External consumer needs one namespace as separate gem | Medium | Medium | ADR-0002 spells out extraction trigger and procedure |
| Council fix re-litigated mid-build | Low | High | Every reviewer invocation re-receives rev2 verdict file path; rev2 is source of truth |
| Old 10 repos stay visible and confuse new users | High if not archived | Medium | Phase 4 archive + redirect README pattern; greys them out in profile |

## Decision

- [x] Approved
- [ ] Rejected
- [ ] Deferred

**Rationale:** Council rev2 unanimously rejected the ten-gem topology. Topology A (one gem, ten namespaces) got 4 of 7 seats explicit and 0 dissenters on the topology itself. The remaining 3 seats refined toward 2-3 gems but only conditional on marketplace ambition being load-bearing today (it is not — no marketplace consumer exists yet; ADR-0002 makes the extraction reversible). Defense Points 6, 7, 9 earned structural carveouts that change the implementation plan inside the merged gem. Build proceeds.
