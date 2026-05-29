# Requirements Traceability Matrix — wild

> Engineer-owned MoSCoW tags. AI must not lower a `MUST` to `SHOULD`/`COULD`/`WON'T` without explicit engineer override.

**Last rebuild:** 2026-05-28
**Source documents:**
- `000-docs/002-PP-PRD-product-requirements.md` (FR-1..9, NFR-1..7)
- `/home/jeremy/000-projects/wild/wild-rails-ai-ops/000-docs/013-AT-AUDT-thinker-council-verdict-rev2-2026-05-29.md` (F1..F10, MIN-Kleppmann, MIN-Karpathy, MIN-Armstrong)
- `.beads/issues.jsonl` (`wild-rvv.*` bead tree)
- `000-docs/adr/ADR-0001-topology.md`
- `000-docs/adr/ADR-0002-namespace-extraction-policy.md`

## Coverage summary

| MoSCoW tier | Total | Covered by test | Uncovered |
|---|---|---|---|
| MUST | 14 | 1 | 13 (all P1 deliverables — Role 5 onwards) |
| SHOULD | 8 | 0 | 8 |
| COULD | 4 | 0 | 4 (deferred — v0.2+) |
| WON'T | 5 | n/a | excluded |

## MUST requirements (P0 blocking — uncovered MUSTs trigger handoff)

| REQ ID | Title | Source | Bead | Test(s) | Status |
|---|---|---|---|---|---|
| REQ-001 | Topology: one gem, ten namespaces with `Wild::Engine` Rails engine | ADR-0001 | wild-rvv (master epic) | `spec/engine/version_spec.rb` (partial: asserts the 7 namespace nested accessors exist) | **Partial — namespaces are placeholders** |
| REQ-002 | One `Wild::Configuration` block replaces 9 broken Configuration singletons | F1 | wild-rvv.1.1 | (none) | **Uncovered — Role 4/5 P1** |
| REQ-003 | Every `CapabilityGate` `rescue` emits a structured audit event; `:evaluation_error` is hard-fail | F2 | wild-rvv.4.1 | (none — `spec/wild/capability_gate/audit_liveness_spec.rb` is a Role 6 deliverable) | **Uncovered — Role 6 P1** |
| REQ-004 | Judgment tests, not vanity counts | F3 | wild-rvv.7.1 | (none — F3 is a discipline policy, enforced by PR template + CHANGELOG) | **Discipline declared in `tests/TESTING.md`; per-namespace assertions land with Role 5/7** |
| REQ-005 | Shared `schemas/wildcard_corpus.yml` matches identically in permission analyzer and capability gate | F4 | wild-rvv.1.2 | (none — Role 4/6 P1) | **Uncovered** |
| REQ-006 | Downgrade `Wild::Skillops` claims to match what code can back up (no atomicity/durability claims) | F5 | wild-rvv.8.1 | (none — doc-trim + code-trim) | **Uncovered — Role 5 + Role 3 re-engage P1/P2** |
| REQ-007 | `Wild::Error` base hierarchy with consumer-distinguishable subclasses | MIN-Armstrong | wild-rvv.1.3 | (none — `spec/engine/error_spec.rb` is a Role 5 deliverable; only the base class skeleton exists in `lib/wild/error.rb`) | **Skeleton only** |
| REQ-008 | `bin/wild-mcp-introspection` + `bin/wild-mcp-admin` ship as `bin/` scripts (not separate gems) with versioned `prompts/<tool>.md` + `schemas/<tool>.yml` | MIN-Karpathy | wild-rvv.2.1 | (none — stub `bin/` scripts exit 1 with pending message) | **Uncovered — Role 9 P2** |
| REQ-009 | `rails g wild:install` writes 3 config files + mounts engine; works under 5-minute stopwatch | F9 + DHH non-negotiable | wild-rvv.9.1 | (none — generator stub only) | **Uncovered — Role 8 P2** |
| REQ-010 | DI container around `ActiveJob`/`Rails.cache`/`Flipper` deleted; adapters defaulted | DHH Week 2 plan | wild-rvv.3 (admin_tools epic) | (none) | **Uncovered — Role 5 P1** |
| REQ-011 | Wild ecosystem v0.1.0 cuts only after all 13 council-fix beads close with evidence | Council rev2 § "What ships in v1.1" | wild-rvv (master epic) | (n/a — release-pipeline gate; `release.yml` checks) | **Pending v0.1.0 release** |
| REQ-012 | MCP transport runs without Rails being loaded (Karpathy-mandated transport-host independence) | MIN-Karpathy | wild-rvv.2.1 | (none — Role 9 P2) | **Uncovered** |
| REQ-013 | Every public method on `Wild::AdminTools` passes through `Wild::CapabilityGate#evaluate` on at least one taint path | DHH § "Per-repo: kill / merge / keep" | wild-rvv.3 (admin_tools epic) | (none — future custom CodeQL query `rb/wild/capability-gate-required`) | **Uncovered** |
| REQ-014 | No fitness-function violations: no `Net::HTTP` under `lib/`, no `Open3` under `lib/` | Council architecture § "Fitness-function suite" | wild-rvv.7 (analyzers epic) | (none — Role 7 P1) | **Uncovered** |

## SHOULD requirements (advisory)

| REQ ID | Title | Source | Bead | Test(s) | Status |
|---|---|---|---|---|---|
| REQ-101 | Boundary normalization in `Wild::Telemetry::Pipeline` (canonical event shape with sequence number) | F7 | wild-rvv.5.1 | (none) | Uncovered — Role 5 P1 |
| REQ-102 | Decomplect identity / value / time in `Wild::Telemetry::Analysis::Gap` | F8 | wild-rvv.5.2 | (none) | Uncovered — Role 5 P1 |
| REQ-103 | Wire OR delete every half-published API surface | F6 | wild-rvv.4.2 | (none) | Uncovered — Role 6 P1 |
| REQ-104 | Cut back BDUF docs that predate any consumer | F10 | wild-rvv.8.2 | (n/a — doc work) | Uncovered — Role 3 re-engage P2 |
| REQ-105 | `Wild::Telemetry::Collector` either fsyncs per append OR drops "append-only audit log" framing | MIN-Kleppmann | wild-rvv.5.3 | (none) | Decision pending — Role 4 P1; v0.1.0 picks the framing-drop option |
| REQ-106 | Per-namespace `rake test:<namespace>` tasks run in < 30s on stock GitHub Actions | NFR-6 | (no bead) | (none — `Rakefile` declares the tasks) | Untimed |
| REQ-107 | Coverage thresholds enforced per-namespace per `codecov.yml` | NFR-1 | (no bead) | (none — Codecov status checks) | Pending CODECOV_TOKEN secret |
| REQ-108 | Tool descriptions versioned under `prompts/<tool>.md` (reviewable code-diff for each change) | NFR-7 | wild-rvv.2.1 | (none) | Uncovered — Role 9 P2 |

## COULD requirements (deferred to v0.2+)

| REQ ID | Title | Source | Disposition |
|---|---|---|---|
| REQ-201 | 30-prompt agent-eval CI gate | Karpathy v2 | v0.2+ |
| REQ-202 | fsync per append in telemetry collector | Kleppmann v2 if durable-log consumer appears | v0.2+ |
| REQ-203 | TLA+ skillops formalization | Lamport | v0.2+ |
| REQ-204 | Supervision tree / FallbackWriter | Armstrong v2 if wild becomes multi-process | v0.2+ |

## WON'T (excluded from coverage math)

| REQ ID | Title | Why won't |
|---|---|---|
| REQ-X01 | Ten separate `wild-*` gemspecs | Council rev2 rejected unanimously; ADR-0001 |
| REQ-X02 | Per-namespace separate `Configuration` classes | F1 fix scope |
| REQ-X03 | Per-namespace separate `version.rb` files | F1 fix scope |
| REQ-X04 | DI container around `Rails.cache` | DHH explicit "Never ship" list |
| REQ-X05 | `USE_LOCAL_CAPABILITY_GATE` env-toggle pattern | DHH explicit "Never ship" list |

## MoSCoW precedence applied

- **Explicit MoSCoW tag in source doc**: 14 MUSTs (council fixes F1-F10 + 3 minority dissents = 13; plus REQ-001 topology = 14)
- **Source default**: PRD § "Functional requirements" FR-1 through FR-9 = mapped to MUSTs above; § "Non-functional" NFR-1 through NFR-7 = mapped to SHOULDs above
- **Engineer override**: none yet (no `tests/TESTING.md` overrides at policy-pin time)
- **Fallback**: SHOULD for everything else

## Orphaned tests (no linked REQ)

| Test | Reason | Action |
|---|---|---|
| `spec/engine/version_spec.rb` | Links to REQ-001 (topology — partial) | Keep; expand to assert REQ-001's other contracts as Role 4 lands typed `Wild::Configuration` |

No other tests exist yet.
