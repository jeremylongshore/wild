# TEST_AUDIT — wild

**Date:** 2026-05-28
**Branch:** `feat/test-baseline`
**Auditor:** `audit-tests` skill (Intent Solutions Testing SOP)
**Repo:** `jeremylongshore/wild` (P0 complete; namespaces are placeholders)

---

## Executive summary

**Grade: C (62/100)** — reasonable for a fresh-scaffolded engine gem where 90% of the code is yet to land. Not red, not green.

The repo has **strong outer rings (L1 CI, L2 static analysis, L5 CodeQL on PR #6)** and a **valid L3 RSpec foundation with one real spec**. Coverage is unmeasurable today because `bundle install` has not been run in this checkout and the only specs are engine-skeleton tests against placeholder code.

**The honest framing of this audit:** most P0/P1 gaps are EXPECTED at this build phase and are owned by Roles 5/6/7/8/9 in the 4-week build orchestration. The audit's job is to confirm that (a) the testing surfaces ARE planned and bead-tracked, (b) policy thresholds ARE pinned (`tests/TESTING.md`), and (c) the L0 harness + L1 git hooks land NOW so per-namespace work in P1 inherits a working enforcement scaffold.

**Recommended handoff scope:** L0 audit-harness install + L1 git hooks (pre-commit) + the `tests/` scaffolds that this audit just wrote. **Explicitly defer** L3 namespace specs, L4 `spec/dummy/` Rails app, L5 perf/chaos, L6 Gherkin, and L7 UAT — none should be installed against placeholder `.keep` files.

---

## Freshness

```
audit-harness: installed=none latest=0.1.0
```

The wild repo does NOT yet have `@intentsolutions/audit-harness` installed. This is an L0 install gap — addressed in the handoff payload below.

---

## Classification (confirmed)

| Field | Value |
|---|---|
| Repo type | `library` (Ruby gem) |
| Specific shape | Rails engine gem (`lib/wild/engine.rb`) |
| Primary language | Ruby (3.2 / 3.3 / 3.4 matrix) |
| Test framework | RSpec |
| Package manager | Bundler |
| Monorepo? | No |
| MCP transports? | Yes (stub) |
| Current build phase | P0 complete; pre-Role-5 (P1 code moves) |
| Compliance overlay | none |

---

## Applicable layers (taxonomy mapping)

| Layer | Name | Applicability | Status | Notes |
|---|---|---|---|---|
| L1 | Git hooks & CI enforcement | Required | Partial | CI fully wired (`ci.yml`, `codeql.yml`, `release.yml`); **pre-commit hooks ABSENT** (P0 gap) |
| L2 | Static analysis & linting | Required | Installed | RuboCop, Packwerk (root config; per-namespace `package.yml` lands with Role 4 in P1), brakeman, bundler-audit |
| L3 | Unit & function | Required | Stub-only | RSpec + SimpleCov + Cobertura configured; only `spec/engine/version_spec.rb` exists. Coverage gates pinned in `codecov.yml` (85% repo-wide, 80% per-namespace, 85% capability_gate security-critical, 90% engine core, 75% per-file) but unmeasurable today |
| L4 | Integration & regression | Required (engine integration via dummy Rails app) | Absent | `spec/dummy/` Rails app does not exist; lands in P2 (Role 8 + 9) |
| L5 | System quality | Conditionally required | Partial | CodeQL `security-extended` on PR #6 (not yet merged); performance / chaos waived per engineer policy; a11y N/A (no UI) |
| L6 | E2E / BDD / Gherkin | Conditional | Waived | DHH F10 — no BDUF docs before consumers. Stopwatch test (DHH-mandated v0.1.0 gate) covers acceptance in `spec/stopwatch/` without Gherkin ceremony |
| L7 | Acceptance & business validation (UAT) | Conditional | Waived | Stopwatch test IS the v0.1.0 acceptance gate |

**Waived per engineer policy:** L3 mutation testing, L3 property testing, L3 CRAP scoring, L4 integration, L5 perf/chaos/a11y, L6 Gherkin, L7 UAT. Each waiver has an explicit revisit milestone in `tests/TESTING.md § Waived layers`.

---

## Per-layer presence / config / enforcement

| Layer + tool | Present | Configured | Enforced | Hash-pinned |
|---|---|---|---|---|
| L1 CI `ci.yml` | Yes | Yes | Yes (PR + push) | No (harness not installed) |
| L1 CI `release.yml` | Yes | Yes | workflow_dispatch only | No |
| L1 CI `codeql.yml` | Yes (PR #6) | Yes | Pending merge | No |
| L1 Dependabot | Yes | Yes | Weekly Monday | No |
| L1 pre-commit / lefthook / husky | **No** | n/a | n/a | n/a |
| L2 RuboCop | Yes | Yes | CI | No |
| L2 Packwerk | Yes (root) | Partial (no per-ns `package.yml`) | CI | No |
| L2 brakeman | Yes | Yes | CI | No |
| L2 bundler-audit | Yes | Yes | CI | No |
| L3 RSpec | Yes | Yes | CI matrix | No |
| L3 SimpleCov | Yes | Yes (`COVERAGE=1`) | CI matrix | No |
| L3 Codecov | Yes | Yes | CI (token missing) | No |
| L3 mutation | No | n/a | n/a | n/a |
| L3 property | No | n/a | n/a | n/a |
| L3 CRAP (rubycritic) | No | n/a | n/a | n/a |
| L4 spec/dummy Rails | No | n/a | n/a | n/a |
| L5 CodeQL | Yes (PR #6) | Yes | Pending merge | n/a (config is itself the contract) |
| L6 Gherkin | n/a (waived) | — | — | — |
| L7 UAT | n/a (waived) | — | — | — |

---

## Quality gates (deterministic measurements)

| Gate | Result | Notes |
|---|---|---|
| RuboCop (L2) | Not run locally | `bundle install` not yet run in this checkout; CI runs this on every PR |
| Packwerk (L2) | Not run locally | Same |
| brakeman (L2) | Not run locally | Same |
| bundler-audit (L2) | Not run locally | Same |
| RSpec coverage (L3) | Not measured | One spec exists; Bundle not installed locally; first measurement on CI |
| Mutation kill rate (L3) | n/a | Gate not installed (waived per policy until P1) |
| CRAP score (L3) | n/a | Gate not installed (waived per policy until P1) |
| Architecture (L2 Packwerk) | Partial | Root config only; per-namespace `package.yml` lands with Role 4 P1 |
| Bias count (L3) | n/a | Audit-harness not installed (L0 gap) |
| Gherkin lint (L6) | n/a | Waived |
| Escape-scan | n/a | No staged diff |

**No gate failure halts the audit.** Per spec: missing framework = record gap; skip measurement.

---

## P0 gaps (3)

**P0** = ship-blocking OR uncovered MUST. Council rev2 framing applies.

| # | Gap | Layer | Owner | Bead |
|---|---|---|---|---|
| P0-1 | `@intentsolutions/audit-harness` (vendored install) not present at `.audit-harness/`. L0 install required so the in-repo enforcement scaffold exists before per-namespace tests land. | L0 | implement-tests handoff | (file new bead) |
| P0-2 | No pre-commit / commit-msg / pre-push hooks. L1 git-hook layer is missing the per-commit branch (CI catches it later but feedback loop is wrong). | L1 | implement-tests handoff | (file new bead) |
| P0-3 | 13 of 14 MUST requirements uncovered in RTM (council fixes F1-F10 + MIN-Karpathy + MIN-Armstrong + DI/REQ-010). **Expected at this build phase** — owned by Roles 4/5/6/7/8/9 per build orchestration. Tracked as `wild-rvv.1.1` through `wild-rvv.9.1`. | L3 | Roles 4-9 (P1/P2) | `wild-rvv.*` (already filed) |

**Important context for P0-3**: this is NOT a sign the build is off-track. The 13 MUSTs are bead-tracked, owned, sequenced, and gate v0.1.0 ship. `audit-tests` flags them per spec (uncovered MUST = P0); the build plan's existing role assignments are the resolution. No new beads required.

## P1 gaps (6)

**P1** = high-priority advisory.

| # | Gap | Layer | Disposition |
|---|---|---|---|
| P1-1 | `Codecov` upload step exists but `CODECOV_TOKEN` secret not set on GitHub. CI's `fail_ci_if_error: false` prevents block but coverage doesn't appear on Codecov dashboard. | L1/L3 | One-time interactive step by user; file bead |
| P1-2 | Per-namespace Packwerk `package.yml` files do not exist (Role 4 P1 deliverable). Boundary lint runs against root config only. | L2 | Role 4 P1 (`wild-rvv.1` engine epic) |
| P1-3 | 5 SHOULD requirements uncovered in RTM (REQ-101, REQ-102, REQ-103, REQ-105, REQ-108 — all Role 5/6/9 P1/P2 deliverables) | L3 | Roles 5/6/9 P1/P2 |
| P1-4 | 4 of 5 personas have <10% flow coverage (Rails Tech Lead, MCP Consumer, Security Reviewer, Maintainer at 25%) | L3-L4 | Role 7 P1 + Role 8 P2 + Role 9 P2 |
| P1-5 | 13 P0-severity untested journey steps (J1 stopwatch journey is all untested) | L3-L4-L7 | Role 8 (stopwatch fixture) + Role 9 (MCP transport) P2 |
| P1-6 | No characterization-test pattern documented yet (F3 + Beck Refinement #2 requirement before code moves) | L3 | Role 7 P1 (`wild-rvv.7.1`) |

## P2 (informational)

- `bundle install` not yet run; `Gemfile.lock` absent. First CI run will materialize it.
- No `.audit-harness/` cache directory. Created by the L0 install step.
- No per-namespace `THREAT_MODEL.md` files (P1 deliverable per `000-docs/003-AT-ARCH-architecture.md`).

---

## RTM summary (from `tests/RTM.md`)

| MoSCoW | Count | Covered | Uncovered |
|---|---|---|---|
| MUST | 14 | 1 | 13 |
| SHOULD | 8 | 0 | 8 |
| COULD | 4 | 0 | 4 (deferred v0.2+) |
| WON'T | 5 | n/a | excluded |

## Persona coverage summary (from `tests/PERSONAS.md`)

| Persona | Flows | Tested | Coverage |
|---|---|---|---|
| Rails Tech Lead | 7 | 0 | 0% |
| MCP Consumer (non-Rails) | 5 | 0 | 0% |
| Security Reviewer | 6 | 0 | 0% (Note: 3 doc-checks count as covered structurally) |
| Maintainer | 4 | 1 | 25% |

## Journey coverage summary (from `tests/JOURNEYS.md`)

| Journey | Steps | Tested |
|---|---|---|
| J1 Rails developer (stopwatch) | 11 | 0 |
| J2 MCP consumer | 5 | 0 |
| J3 Security reviewer | 6 | 1 (CodeQL pending) |
| J4 Maintainer | 4 | 1 (CI runs) |

## Escape-scan

**N/A** — no staged diff.

---

## Recommended `/implement-tests` handoff scope

Per the user's explicit "do not install layers that would only test placeholder `.keep` files" guidance — **the handoff scope is intentionally narrow**:

### Install NOW (in this PR or a sibling PR)

| Layer | What | Why now |
|---|---|---|
| **L0** | Vendor `@intentsolutions/audit-harness` via `install.sh` into `.audit-harness/` | The in-repo enforcement scaffold all later layers reference (hooks + CI). Per Testing SOP rule "enforcement travels with the code." |
| **L1** | Install `lefthook` (Ruby-friendly git hook manager): pre-commit (RuboCop on staged), commit-msg (conventional-commits regex), pre-push (RSpec smoke on changed `lib/` paths) | Closes the per-commit feedback loop CI alone can't provide; lands once and inherits per-namespace specs as they arrive |
| **tests/** | `tests/TESTING.md` + `tests/RTM.md` + `tests/PERSONAS.md` + `tests/JOURNEYS.md` scaffolds (already written by this audit) | Lands the engineer-policy substrate Role 4/5/6/7 read from |
| **Hash manifest** | `.harness-hash` init via `audit-harness init` after engineer reviews the scaffolds | Pins the policy floor; future AI edits trigger CHALLENGE/REFUSE |

### Defer (do NOT install in this handoff)

| Layer | What | When |
|---|---|---|
| L3 per-namespace specs | Awaiting Role 5 code moves; no code → no judgment tests → just vanity stubs | Role 7 P1 (`wild-rvv.7.1`) |
| L3 mutation testing | Awaiting Role 5 | End of P1 |
| L3 property testing | Awaiting Role 4/5 | End of P1 |
| L3 CRAP scoring | Awaiting Role 5 (133 LOC of skeleton produces meaningless score) | End of P1 |
| L4 `spec/dummy/` Rails app | Awaiting Role 8 generator + Role 9 MCP transport | P2 |
| L4 contract tests for MCP | Awaiting Role 9 | P2 |
| L5 perf / chaos | Waived for v0.1.0 | v0.2+ |
| L6 Gherkin | Waived (F10) | v0.2+ or first consumer's stable flow |
| L7 UAT | Stopwatch is the gate | n/a for v0.1.0 |

---

## Handoff payload

```json
{
  "classification": {
    "repo_type": "library",
    "subtype": "rails-engine-gem",
    "language": "ruby",
    "ruby_versions": ["3.2", "3.3", "3.4"],
    "package_manager": "bundler",
    "test_framework": "rspec",
    "monorepo": false
  },
  "tests_md_path": "tests/TESTING.md",
  "p0_gaps": [
    {"layer": "L0", "what": "audit-harness vendored install"},
    {"layer": "L1", "what": "pre-commit hook manager (lefthook recommended for Ruby)"},
    {"layer": "L3", "what": "13 uncovered MUST requirements — EXPECTED at this phase; bead-tracked; do NOT scaffold against placeholder lib/wild/<ns>/.keep files"}
  ],
  "p1_gaps": [
    {"layer": "L1/L3", "what": "CODECOV_TOKEN secret missing on GitHub Actions"},
    {"layer": "L2", "what": "per-namespace Packwerk package.yml — Role 4 P1 deliverable, not implement-tests"},
    {"layer": "L3", "what": "5 SHOULD requirements uncovered — Roles 5/6/9 P1/P2"},
    {"layer": "L3-L4", "what": "personas below threshold — Role 7 P1 + Role 8/9 P2"},
    {"layer": "L3-L7", "what": "13 P0 untested journey steps — Role 8 stopwatch + Role 9 MCP P2"},
    {"layer": "L3", "what": "characterization-test pattern not yet documented — Role 7 P1"}
  ],
  "rtm_gaps": [
    "REQ-002", "REQ-003", "REQ-005", "REQ-006", "REQ-007", "REQ-008", "REQ-009",
    "REQ-010", "REQ-011", "REQ-012", "REQ-013", "REQ-014"
  ],
  "persona_gaps": ["Rails Tech Lead", "MCP Consumer (non-Rails)", "Security Reviewer", "Maintainer"],
  "journey_gaps": ["J1 (all 11 steps)", "J2 (all 5 steps)", "J3 (4 of 6 steps)", "J4 (3 of 4 steps)"],
  "install_order": [
    "L0 (audit-harness vendored install)",
    "L1 (lefthook + 3 hooks)",
    "harness-hash init"
  ],
  "scope_exclusions": [
    "Do NOT scaffold per-namespace L3 tests against placeholder .keep files",
    "Do NOT install L4 spec/dummy/ Rails app (Role 8 P2 owns)",
    "Do NOT install L5 perf/chaos tools (waived for v0.1.0)",
    "Do NOT install L6 Cucumber / .feature files (waived per F10)",
    "Do NOT install L7 UAT lifecycle (stopwatch test is the gate)",
    "Do NOT modify .rubocop.yml, packwerk.yml, codecov.yml (already engineer-owned)",
    "Do NOT modify ci.yml or release.yml (already present and working)"
  ],
  "engineer_owned": [
    "tests/TESTING.md § Classification, § Thresholds, § Waived layers, § Compliance overlay",
    "codecov.yml (already engineer-owned)",
    ".rubocop.yml",
    "packwerk.yml (root config; per-namespace package.yml is Role 4)",
    "RTM.md MoSCoW tags (no AI lowering of MUST)"
  ]
}
```

---

## What this audit did NOT touch

- `lib/wild/**` — no code modification (Role 5 owns code moves)
- `bin/wild-mcp-*` — stub scripts unchanged
- `.rubocop.yml`, `packwerk.yml`, `codecov.yml` — engineer-owned
- `.github/workflows/*` — existing CI/CodeQL/Release workflows unchanged
- Any council fix beads (`wild-rvv.*`) — no closures, no edits
- The CodeQL PR #6 — untouched on `feat/codeql-baseline`

## Files this audit wrote (transient + tracked)

| File | Status | Owner after this commit |
|---|---|---|
| `TEST_AUDIT.md` | Transient (delete after `/implement-tests` runs OR after engineer reviews) | n/a |
| `tests/TESTING.md` | Tracked; § Classification + § Thresholds + § Waived layers + § Compliance overlay are ENGINEER-OWNED from this point | Engineer (Jeremy) |
| `tests/RTM.md` | Tracked; MoSCoW tags ENGINEER-OWNED; AI updates row coverage only | Engineer |
| `tests/PERSONAS.md` | Tracked; persona definitions ENGINEER-OWNED; AI updates coverage % | Engineer |
| `tests/JOURNEYS.md` | Tracked; journey definitions ENGINEER-OWNED; AI updates step status | Engineer |

---

## Next steps

1. Engineer (Jeremy) reviews this `TEST_AUDIT.md` + the four `tests/*.md` scaffolds
2. Approve handoff to `/implement-tests` with the narrow scope above (L0 + L1 + harness-hash init)
3. After `/implement-tests` lands → run `pnpm exec audit-harness init` (or vendored equivalent) to pin the policy floors
4. Commit on `feat/test-baseline` and open PR
5. File one bd bead for the `CODECOV_TOKEN` interactive step (`wild-rvv.codecov-token`)
6. End of P1 (Role 7 green CI): re-run `/audit-tests` and lift waivers that are no longer justified

## Validation evidence

- YAML safe-load on all workflow + config files: passed (from CodeQL audit earlier this session)
- `bd list --label thinker-council`: returns 13 beads (verified earlier)
- Branch isolation: this audit runs on `feat/test-baseline`, separate from `feat/codeql-baseline` (PR #6) and `main`
- No code under `lib/wild/<namespace>/` was inspected or modified (all are `.keep` placeholders)
- Council rev2 verdict path quoted at every reviewer entry point in the scaffolds (Testing SOP requirement)

## Limitations

- **Local CodeQL not executable** (CLI not installed). First CodeQL output is the PR #6 workflow run.
- **Local RSpec not executable** (`bundle install` not yet run). First coverage measurement is the next CI run.
- **Audit-harness not yet installed**. Hash-pinning impossible until the L0 install lands.
- **`dhh-reviewer` agent not loadable this session**. Build orchestration substitutes `martin-fowler-reviewer` for the relevant gates per the build plan.
