# TEST_AUDIT.md — wild

**Date:** 2026-05-31
**Branch:** `feat/role6-pr1-f2-audit-emission`
**Auditor:** `/audit-tests` (post-namespace-move re-audit — all 10 `Wild::*` namespaces consolidated)
**Prior audit:** 2026-05-28 grade C (62/100), pre-namespace-move

---

## Grade: A− (90/100)

The Rails-engine-gem CI/CD + testing infrastructure is **complete and correct** for the
v0.1.0 build phase. Reality is materially stronger than the (stale) `tests/TESTING.md`
prose claims. No P0 gaps. The deductions are: per-file coverage floor still commented
out (P1), stale doc drift in TESTING.md (P2 — partially fixed by this audit), and the
engineer-waived deeper layers whose *rationale* now needs re-justification.

## Classification (confirmed)

| Field | Value |
|---|---|
| Repo type | `library` — Rails **engine** gem (+ secondary CLI surface: 2 `bin/wild-mcp-*`) |
| Language | Ruby 3.2 / 3.3 / 3.4 matrix |
| Framework | RSpec (3.13) + rspec-rails (8.0); SimpleCov + Cobertura → Codecov |
| Boundaries | Packwerk — root + 10 per-namespace `package.yml` all present |
| Namespaces | 10 `Wild::*` fully implemented (227 lib `.rb`); NOT placeholders |

## Verified ground truth (this audit)

- **2988 rspec examples, 0 failures** across all 10 namespaces.
- **98.29% line coverage** (6252/6361) — far above the 85% repo floor.
- All 11 `package.yml` boundary files present (root + 10 namespaces).
- CodeQL `security-extended` merged to main (PR #6, 2026-05-29); runs on PRs.
- `CODECOV_TOKEN` set (2026-05-30); Codecov upload + 9 per-component status checks live.
- The 10 "orphan facade" loaders (`skillops.rb` 106L, `admin_tools.rb` 89L, etc.) and
  `engine.rb` are at **100% line coverage** — exercised through namespace specs. The
  "no mirrored `_spec.rb`" signal is a file-naming artifact, **not a coverage gap**.
- Zero genuinely skipped/pending/focused tests (23 "skip/pending" hits are all domain
  vocabulary in flake-parser status handling).

## Per-layer map

| Layer | Status |
|---|---|
| L1 git hooks + CI | **Installed** — ci/release/codeql workflows; plain-shell hooks + installer; dependabot. lint/test/security block on main+PRs. |
| L2 static/lint/sec | **Installed**: RuboCop, Packwerk (`validate` + `+11 package.yml` `check`, both required, no `continue-on-error`), brakeman (scans `lib/` since review-wave f-x2-1, previously scanned the then-empty `spec/dummy/`), bundler-audit, CodeQL. `spec/dummy/` landed (review-wave f-x2-1/f-x2-2), so this row's prior "continue-on-error until spec/dummy/ lands" is stale, corrected here. |
| L3 unit | **Installed**: 3083+ ex / 10 namespaces (review wave, 2026-08-25; up from 2988 at this audit's original date); SimpleCov `minimum_coverage 85` enforced under COVERAGE=1; Codecov live. |
| L3 mutation / property / CRAP | **Waived (engineer policy)** — rationale now stale (see P1-2). |
| L4 integration | **Installed**: `spec/dummy/` landed (review-wave f-x2-1/f-x2-2); row below at P2 gaps is stale on this point. |
| L5 SAST (CodeQL) | **Installed** — live gate on main. |
| L5 perf / chaos / a11y | **Waived** (perf/chaos v0.2.0; a11y permanent — no UI). |
| L6 BDD/Gherkin | **Waived (v0.2.0)** — stopwatch test substitutes. |
| L7 UAT | **Waived (v0.1.0)** — 5-min stopwatch test is the acceptance gate; RTM/PERSONAS/JOURNEYS authored. |

## P0 gaps

**None.** L1/L2/L3 installed and CI-enforced; coverage gate, Codecov, CodeQL all live.

## P1 gaps

1. **Per-file coverage floor not enforced** — `minimum_coverage_by_file 75` is commented
   out in `spec/spec_helper.rb:40`. `TESTING.md § Thresholds` declares 75% as policy. The
   F3 "vanity against placeholder code" rationale that justified disabling it is now false
   (namespaces fully implemented at 98% line coverage). **Lift-able now** — engineer
   uncomments + re-pins. (Engineer-owned policy line; not AI-edited.)
2. **Mutation / property / CRAP waiver rationale is stale** — all three were waived "for
   P0/P1" citing "placeholder `.keep` files / 133 LOC skeleton." That premise is false now.
   Per the TESTING.md revisit triggers ("End of P1"), the decision point has fired:
   re-defer with current rationale or install (`mutant`/`stryker-rb`, `rantly`, `rubycritic`).
   Engineer decision.

## P2 gaps

3. ~~**`spec/dummy/` absent**~~ **CLOSED** (review-wave f-x2-1/f-x2-2, 2026-08-25): `spec/dummy/`
   landed; Packwerk `boundary` + brakeman are required, blocking checks, not `continue-on-error`.
4. **TESTING.md doc drift** — `## Installed gates` + `## Last audit` written at P0 are
   factually wrong (one-spec framing, package.yml "ABSENT", CODECOV_TOKEN "missing", CodeQL
   "not merged"). **Observational sections fixed by this audit.** The `## Classification`
   "placeholder .keep files" line + waiver rationales (policy sections) flagged for engineer.
5. **`.harness-hash` 0 files pinned** — expected (no Gherkin / JS-Python arch configs to
   discover). Informational.

## Deferred behavior work (NOT test-infra gaps — correctly bead-tracked)

These are open `wild-rvv` beads owned by Roles 6/7/8/9; their absence is **by design** at
this phase, not an audit failure:
- F2 audit-emission (`wild-rvv.4.1` — in progress this session)
- F7/F8 telemetry decomplecting (`wild-rvv.5.1`/`.5.2`), MIN-Kleppmann (`.5.3`)
- F3 golden-corpus tests (`wild-rvv.7.1`), F6 export audits (`.5.4`, `.8.3`)
- `rails g wild:install` generator spec + `spec/dummy/` (Role 8)
- MCP `bin/` wiring + Hooks::McpServer consumption (Role 9)
- DI adapter defaulting (`wild-rvv.u16`, `wild-rvv.uku`, `.3.1`)

## Moved-code debt (observational)

44 `# rubocop:disable` directives across `lib/wild/` — grandfathered metric/style
exceptions from the 12 structure-move PRs (ParameterLists on domain value objects,
AbcSize on aggregation methods, etc.). Behavior-preserving; candidates for refactor
when the deferred behavior beads touch those files.

## Escape-scan

Clean (exit 0). No coverage-floor lowering, no `.feature` mutation, no MUST downgrades.

## Handoff

**None.** No P0/P1 gap requires `implement-tests` scaffolding — all infrastructure is
present. The P1 items are engineer-owned policy decisions (lift per-file floor; re-justify
or install the waived L3 gates), not missing test infrastructure.
