# Status: wild

> Current state of the consolidation build against the 4-week plan.

**Author:** Jeremy Longshore
**Date:** 2026-08-26 (Role 6 paused 2026-06-02; strategic review-wave closeout)
**Status:** P1 paused — Roles 4 ✓, 5 ✓, 6 ⏸ paused (F2 epic closed), **6.5 ✓ review wave complete**, 7 ○ not started

> Canonical live state: `/home/jeremy/000-projects/wild/build-orchestration/STATUS.md`. This doc mirrors its summary.

## Build plan summary

5 phases, 11 roles, 4 weeks. Full plan + per-role briefing packets live at
`/home/jeremy/000-projects/wild/build-orchestration/`.

| Phase | Span | Output | Status |
|---|---|---|---|
| P0 — Foundation | Week 1 days 1-3 | Empty repo with skeleton, bd initialized, 13 fixes filed as beads, governance docs + ADRs | **✓ Complete** |
| P1 — Library collapse | Week 1 day 4 → Week 2 day 3 | Ten old gems' `lib/` trees moved into `lib/wild/<namespace>/`, F1-F5 + F6/F7 fixes landed | **⏸ Paused 2026-06-02 → review interlude 2026-08-25** (Roles 4✓ 5✓ 6⏸ 6.5▸ 7○) |
| P2 — Rails-native shape | Week 2 days 4-7 | `Wild::Engine` mounts; `rails g wild:install`; defaulted adapters; `prompts/` + `bin/eval` | Pending |
| P3 — Plugin layer | Week 3 | `plugins/wild/` directory with MCP servers + skill + agent + slash commands + hook | Pending |
| P4 — Adoption proof + cutover | Week 4 | Stopwatch test passes; v0.1.0 cuts; 10 old `wild-*` repos archived with redirect READMEs; umbrella README updated | Pending |

## Live progress (P1)

### Done

- [x] **P0 foundation** — repo, skeleton, governance, ADR-0001/0002, beads, orchestration scaffolding (2026-05-28)
- [x] **Role 4 (engine architect)** — `wild-rvv.1` epic closed: one typed `Wild::Configuration` (F1), schemas-as-data substrate (F4), `Wild::Error` hierarchy (MIN-Armstrong), ADR-0003 four-tier DAG, root + 10 per-namespace `package.yml`
- [x] **Gate 1** — engine shape passed (code moves proceeded; per-PR Fowler/Armstrong/Hickey reviews ongoing)
- [x] **Role 5 (ruby refactor)** — all 10 namespaces moved into `lib/wild/<namespace>/` (PRs #20–#31; #31 final). 227 lib files, ~3060 specs, 0 failures, RuboCop clean
- [x] **Role 6 (security boundary) — partial, paused 2026-06-02** — F2 audit-emission core (#32), detect_cycle tri-color DFS (#33), F4 corpus reconcile (#34), cut max_prerequisite_depth (#35), F2 ordering + hole (#36), F2 shape↔schema (#37), status reconcile (#40), **F2 emit-time schema validator (#41) closing the F2 epic**, Gate-rescue contract pinned (#42), vendored audit-harness 1.1.5 (#43)
- [x] **Role 6.5 (strategic review interlude) — completed 2026-08-26.** Plan of record: [`009-PP-PLAN`](009-PP-PLAN-strategic-review-and-fix-wave-2026-08-25.md); review record: [`010-RA-REVW`](010-RA-REVW-review-wave-findings-and-bead-docket-2026-08-25.md). All remediation and verifier Beads are closed through PR #85; closeout gate receipt: 3,325 RSpec examples, RuboCop/Packwerk clean, Brakeman 0 warnings, Bundler Audit 0 vulnerabilities. Stage 4 AAR and showcase decision are tracked under `wild-vfo.4`.

### Next up (Role 6.5 → Role 6 remaining → Role 7)

- [ ] Role 6.5 closeout: file the AAR and record the showcase decision; remediation and verifier work is complete.
- [ ] `wild-rvv.4.2` (F6 half-published audit), `wild-rvv.5.1`/`.5.2` (F7/F8), `wild-rvv.5.3` (MIN-Kleppmann), `wild-rvv.6.2` (Hooks::Audit)
- [ ] Role 6 follow-ups: `wild-0c3` (dark-audit ALLOW posture), `wild-28y` (inert `on_evaluation_error`)
- [ ] Role 7 (`test-automator`): `wild-rvv.7.1` (F3 vanity-test sweep) + `wild-rvv.7.2`

## Council fix tally

**4 of 13 fully closed** (F1, F2, F4, MIN-Armstrong). F2 closed via #41 (emit-time validator) + #42 (Gate-rescue contract). detect_cycle + max_prerequisite_depth follow-ups also closed. **Known regression:** F1's own close criterion (`rg 'class Configuration' lib` → 0) now returns 3 after the Role 5 moves; re-checked in the review wave. Full ledger in `build-orchestration/STATUS.md`.

## Open blockers

| Blocker | Owner | Mitigation |
|---|---|---|
| Suite was red on `main` 2026-06-17 → 2026-08-25 (wall-clock fixture + timing assertion) | review wave | Fixed in #52; `ci-ok` fan-in + branch protection on `main` (#51) so it cannot silently rot again |
| Packwerk + brakeman lanes cannot pass without a Rails app (`spec/dummy/`), so ADR-0003 is enforced only in prose and `release.yml` cannot run | review wave | `spec/dummy/` PR in the fix wave, or the two lanes are removed with a STATUS line |

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
