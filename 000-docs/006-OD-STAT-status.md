# Status: wild

> Current state of the consolidation build against the 4-week plan.

**Author:** Jeremy Longshore
**Date:** 2026-06-01 (Role 6 in progress; work paused for checkpoint)
**Status:** P1 in progress — Roles 4 ✓, 5 ✓, 6 ▸ in progress, 7 ○ not started

> Canonical live state: `/home/jeremy/000-projects/wild/build-orchestration/STATUS.md`. This doc mirrors its summary.

## Build plan summary

5 phases, 11 roles, 4 weeks. Full plan + per-role briefing packets live at
`/home/jeremy/000-projects/wild/build-orchestration/`.

| Phase | Span | Output | Status |
|---|---|---|---|
| P0 — Foundation | Week 1 days 1-3 | Empty repo with skeleton, bd initialized, 13 fixes filed as beads, governance docs + ADRs | **✓ Complete** |
| P1 — Library collapse | Week 1 day 4 → Week 2 day 3 | Ten old gems' `lib/` trees moved into `lib/wild/<namespace>/`, F1-F5 + F6/F7 fixes landed | **▸ In progress** (Roles 4✓ 5✓ 6▸ 7○) |
| P2 — Rails-native shape | Week 2 days 4-7 | `Wild::Engine` mounts; `rails g wild:install`; defaulted adapters; `prompts/` + `bin/eval` | Pending |
| P3 — Plugin layer | Week 3 | `plugins/wild/` directory with MCP servers + skill + agent + slash commands + hook | Pending |
| P4 — Adoption proof + cutover | Week 4 | Stopwatch test passes; v0.1.0 cuts; 10 old `wild-*` repos archived with redirect READMEs; umbrella README updated | Pending |

## Live progress (P1)

### Done

- [x] **P0 foundation** — repo, skeleton, governance, ADR-0001/0002, beads, orchestration scaffolding (2026-05-28)
- [x] **Role 4 (engine architect)** — `wild-rvv.1` epic closed: one typed `Wild::Configuration` (F1), schemas-as-data substrate (F4), `Wild::Error` hierarchy (MIN-Armstrong), ADR-0003 four-tier DAG, root + 10 per-namespace `package.yml`
- [x] **Gate 1** — engine shape passed (code moves proceeded; per-PR Fowler/Armstrong/Hickey reviews ongoing)
- [x] **Role 5 (ruby refactor)** — all 10 namespaces moved into `lib/wild/<namespace>/` (PRs #20–#31; #31 final). 227 lib files, ~3060 specs, 0 failures, RuboCop clean
- [x] **Role 6 (security boundary) — partial** — F2 audit-emission core (#32), detect_cycle tri-color DFS (#33), F4 corpus reconcile (#34), cut max_prerequisite_depth (#35), F2 ordering + hole (#36), F2 shape↔schema (#37)

### Next up (Role 6 remaining → Role 7)

- [ ] `wild-rvv.4.1.2` — wire json-schema validator (upgrades the #37 conformance gate), closes F2 epic `wild-rvv.4.1`
- [ ] `wild-rvv.4.2` (F6 half-published audit), `wild-rvv.5.1`/`.5.2` (F7/F8), `wild-rvv.5.3` (MIN-Kleppmann), `wild-rvv.6.2` (Hooks::Audit)
- [ ] Role 6 follow-ups: `wild-0c3` (dark-audit ALLOW posture), `wild-28y` (inert `on_evaluation_error`)
- [ ] Role 7 (`test-automator`): `wild-rvv.7.1` (F3 vanity-test sweep) + `wild-rvv.7.2`

## Council fix tally

**3 of 13 fully closed** (F1, F4, MIN-Armstrong). F2 substantially landed (validator-wiring child remains). detect_cycle + max_prerequisite_depth follow-ups also closed. Full ledger in `build-orchestration/STATUS.md`.

## Open blockers

| Blocker | Owner | Mitigation |
|---|---|---|
| `dhh-reviewer` agent not loadable yet this session | tooling | Substitute `martin-fowler-reviewer` for P1/P2 gates; re-validate when dhh-reviewer becomes loadable |

## Open risks (mirrored from build plan)

| Risk | Mitigation status |
|---|---|
| Role 5 hits hidden cross-namespace coupling not visible in audits | Mitigated: Role 4 runs Packwerk lint pre-move |
| Role 7 reveals tests that passed only in original gem context | Mitigated: characterization-test pattern per Beck Refinement #2 |
| Stopwatch test fails at P4 | Mitigated: dry stopwatch test at end of P2 |
| Plugin (P3) leaks Rails-engine assumptions into MCP transport | Mitigated: Role 10 designs MCP entries as logically independent transports |
| `intent-solutions-io` accidentally touched during build | Mitigated: only Role 11 touches umbrella, only in P4, PR review checklist enforces |

## Cadence

- Status section updated at the end of each phase
- Per-role bead closures append evidence linking back to rev2 verdict file path
- Council fix beads tagged `label:thinker-council` for `bd list` queries
