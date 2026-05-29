# Status: wild

> Current state of the consolidation build against the 4-week plan.

**Author:** Jeremy Longshore
**Date:** 2026-05-28
**Status:** P0 in progress

## Build plan summary

5 phases, 11 roles, 4 weeks. Full plan + per-role briefing packets live at
`/home/jeremy/000-projects/wild/build-orchestration/`.

| Phase | Span | Output | Status |
|---|---|---|---|
| P0 — Foundation | Week 1 days 1-3 | Empty repo with skeleton, bd initialized, 13 fixes filed as beads, governance docs + ADRs | **In progress** |
| P1 — Library collapse | Week 1 day 4 → Week 2 day 3 | Ten old gems' `lib/` trees moved into `lib/wild/<namespace>/`, F1-F5 + F6/F7 fixes landed | Pending |
| P2 — Rails-native shape | Week 2 days 4-7 | `Wild::Engine` mounts; `rails g wild:install`; defaulted adapters; `prompts/` + `bin/eval` | Pending |
| P3 — Plugin layer | Week 3 | `plugins/wild/` directory with MCP servers + skill + agent + slash commands + hook | Pending |
| P4 — Adoption proof + cutover | Week 4 | Stopwatch test passes; v0.1.0 cuts; 10 old `wild-*` repos archived with redirect READMEs; umbrella README updated | Pending |

## Live progress (P0)

### Done

- [x] `jeremylongshore/wild` GitHub repo created (public)
- [x] Local clone at `/home/jeremy/000-projects/wild/wild/`
- [x] 21 governance files written (README, CHANGELOG, LICENSE, CODE_OF_CONDUCT, CONTRIBUTING, SECURITY, SUPPORT, CLAUDE.md, AGENTS.md, .gitignore, .editorconfig, .gitattributes, .github/FUNDING, CODEOWNERS, PR template, issue templates × 3, dependabot, ci.yml, release.yml)
- [x] 6-doc enterprise planning set seeded under `000-docs/`
- [x] ADR-0001 (topology) + ADR-0002 (namespace extraction policy) committed
- [x] Ruby gem skeleton + Wild::Engine skeleton + namespace placeholders
- [x] Initial commit + push to GitHub
- [x] Beads initialized; 13 council fixes filed
- [x] Build orchestration scaffolding at `/home/jeremy/000-projects/wild/build-orchestration/`

### Next up (P1)

- [ ] Role 4 (`backend-architect`): finalize engine architecture + Packwerk `package.yml` per namespace
- [ ] Gate 1: `martin-fowler-reviewer` signs engine shape against ADR-0001 (stand-in until `dhh-reviewer` loadable)
- [ ] Role 5 (`ruby-pro`): move ten old gems' `lib/` into `lib/wild/<namespace>/`
- [ ] Roles 6 + 7: security boundary fixes (F2 audit-blind, `detect_cycle` false-positive) + test consolidation in parallel

## Open blockers

| Blocker | Owner | Mitigation |
|---|---|---|
| `dhh-reviewer` agent not loadable yet this session | tooling | Substitute `martin-fowler-reviewer` for P1/P2 gates; re-validate when dhh-reviewer becomes loadable |
| Packwerk lint pass needed before code moves | Role 4 | Build into Role 4's deliverable; surface coupling violations as beads |

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
