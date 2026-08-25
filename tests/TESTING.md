# Testing policy — wild

> Engineer-owned policy file. AI may update observational sections (## Installed gates, ## Frameworks, ## Last audit, ## Traceability) but not policy sections (## Classification, ## Thresholds, ## Waived layers, ## Compliance overlay).

**Last audit:** 2026-05-31 (post-namespace-move — all 10 namespaces consolidated; grade A− 90/100)
**Policy hash-pin:** `.harness-hash` initialized (0 files pinned — no auto-discoverable artifacts yet)

> **Engineer action items from the 2026-05-31 re-audit** (policy sections — AI did not self-edit):
> 1. `## Classification` line "Namespaces … are placeholder `.keep` files until P1 lands" is now false — namespaces fully implemented. Update when convenient.
> 2. `## Waived layers` mutation/property/CRAP rationale cites placeholder code; that premise is false now. Re-defer with current rationale or install the gates (revisit trigger has fired).
> 3. `spec/spec_helper.rb:40` `minimum_coverage_by_file 75` is still commented out; the F3 placeholder rationale no longer holds — lift it (98.29% line coverage now) + re-pin.

---

## Classification

| Field | Value |
|---|---|
| Repo type | `library` (Ruby gem; specifically a Rails engine gem) |
| Primary language | Ruby (3.2 / 3.3 / 3.4 matrix) |
| Package manager | Bundler |
| Test framework | RSpec |
| Multi-package? | No |
| Engine? | Yes — `Wild::Engine` (Rails engine) |
| MCP transports? | Yes — `bin/wild-mcp-introspection`, `bin/wild-mcp-admin` (P2 implementation) |
| Compliance overlay | none |
| Current build phase | P0 complete; awaiting Role 5 code moves (P1). Namespaces under `lib/wild/<namespace>/` are placeholder `.keep` files until P1 lands. |

## Thresholds (policy — AI must not lower)

| Metric | Floor | Source |
|---|---|---|
| Coverage — repo-wide | 85% | `codecov.yml` (per `000-docs/005-AT-SPEC-technical-spec.md` § Coverage policy) |
| Coverage — per-namespace | 80% | `codecov.yml` |
| Coverage — `capability_gate` | 85% | `codecov.yml` (security-critical) |
| Coverage — `engine` core | 90% | `codecov.yml` |
| Coverage — per-file floor | 75% | `spec/spec_helper.rb` SimpleCov `minimum_coverage_by_file` |
| Mutation kill rate | ≥ 70% | Policy — gate not yet installed (deferred per § Waived layers) |
| CRAP score — prod max | ≤ 30 | Policy |
| CRAP score — test max | ≤ 15 | Policy |
| CRAP score — project avg | ≤ 10 | Policy |
| Architecture violations | 0 | Packwerk (`packwerk.yml`) — enforced |
| Brakeman warnings | 0 | CI `security` job |
| bundler-audit advisories | 0 | CI `security` job |
| Council fix bead closure | 13/13 before v0.1.0 ships | `wild-rvv.*` beads with `label:thinker-council` |

## Compliance overlay

None at v0.1.0.

If a downstream consumer requires HIPAA / SOX / PCI / SOC2 / GDPR / FedRAMP,
add overlay here. SHOULD-tier requirements will then escalate to P0 per RTM
spec.

## Waived layers (engineer policy)

Engineer-declared deferrals. Each entry is reviewed at the end of each build
phase.

| Layer / Gate | Status | Reason | Revisit |
|---|---|---|---|
| L3 mutation testing | Waived for P0/P1 | Namespace `lib/` trees are placeholder `.keep` files until Role 5 code moves land in P1. Mutation testing of 133 LOC of engine + 28 LOC of generator stub is not a judgment test — would produce vanity score against placeholders. (Council F3 framing.) | End of P1: install `mutant` / `stryker-rb`; baseline ≥ 70% kill rate per namespace |
| L3 property testing | Waived for P0/P1 | Same reason. Configuration nested-accessor stub is the only candidate, and Role 4 replaces it in P1 with typed accessors. | End of P1: install `rantly` or `rspec-property` for telemetry pipeline + capability-gate rule evaluation |
| L3 CRAP scoring | Waived for P0/P1 | 133 LOC of engine skeleton produces meaningless CRAP signal | End of P1: install `rubycritic` for combined CRAP + complexity |
| L4 integration tests | Waived for P0 | No `spec/dummy/` Rails app yet; landing in P2 (Role 8 generator + Role 9 MCP transport need a target) | End of P1: scaffold `spec/dummy/` |
| L5 performance / chaos | Waived for v0.1.0 | DHH defer list — premature before real consumer feedback | v0.2.0 |
| L5 accessibility | Permanently waived | Engine gem has no UI surface | n/a |
| L6 BDD / Gherkin | Waived for v0.1.0 | DHH F10 (no BDUF docs before consumers); no `.feature` files until at least one real consumer's golden flow is captured. **Stopwatch test in `spec/stopwatch/` covers the v0.1.0 acceptance gate without Gherkin ceremony.** | v0.2.0 or earlier if a consumer surfaces a stable golden flow |
| L7 UAT | Waived for v0.1.0 | The five-minute stopwatch test IS the v0.1.0 acceptance gate (DHH non-negotiable); formal UAT lifecycle premature | v0.2.0 |

## Installed gates (observational — AI may update)

| Layer | Tool | Status | Wired in |
|---|---|---|---|
| L1 | GitHub Actions CI | Installed, enforced on `main` + PRs | `.github/workflows/ci.yml` |
| L1 | GitHub Actions Release | Installed, `workflow_dispatch` only | `.github/workflows/release.yml` |
| L1 | GitHub Actions CodeQL | Installed (PR #6 — not yet merged to main) | `.github/workflows/codeql.yml` |
| L0 | `.audit-harness/` (vendored v1.1.4) | Installed; wrapper at `scripts/audit-harness`; `.harness-hash` initialized (0 files pinned — no auto-discoverable artifacts yet) | `.audit-harness/`, `scripts/audit-harness`, `.harness-hash` |
| L1 | Local git hooks (plain-shell) | Installed; engineer runs `scripts/install-hooks` once per clone | `scripts/git-hooks/{pre-commit,commit-msg,pre-push}`, `scripts/install-hooks` |
| L1 | Dependabot | Installed | `.github/dependabot.yml` |
| L2 | RuboCop (+ rails + rspec cops) | Installed, CI-enforced | `.rubocop.yml`, `ci.yml lint` job |
| L2 | Packwerk (namespace boundary) | Installed; root + **all 10 per-namespace `package.yml` present**; `spec/dummy/` landed so the lane runs to completion, but `boundary` job stays `continue-on-error`: it reports 465 pre-existing namespace-dependency violations across the ten `package.yml` files, a separate out-of-scope fix | `packwerk.yml`, 11× `package.yml`, `spec/dummy/`, `ci.yml boundary` job |
| L2 | brakeman | Installed, CI-enforced | gemspec dev dep, `ci.yml security` job |
| L2 | bundler-audit | Installed, CI-enforced | gemspec dev dep, `ci.yml security` job |
| L3 | RSpec | Installed — **2988 examples / 0 failures across all 10 namespaces**; 98.29% line coverage | `spec/spec_helper.rb`, `.rspec`, `ci.yml test` matrix |
| L3 | SimpleCov + Cobertura | Installed (gated by `COVERAGE=1`); `minimum_coverage 85` enforced; `minimum_coverage_by_file 75` still commented (P1 — lift-able) | `spec/spec_helper.rb` |
| L3 | Codecov upload | Installed; **`CODECOV_TOKEN` set 2026-05-30**; 9 per-component status checks live | `ci.yml test` job, `codecov.yml` |
| L4 | spec/dummy/ Rails app | Installed (review-wave f-x2-1/f-x2-2); minimal host app mounting `Wild::Engine` at `/wild` for Packwerk + brakeman + `spec/engine/engine_spec.rb` | `spec/dummy/` |
| L5 | CodeQL (`security-extended`) | Installed — **merged to main (PR #6, 2026-05-29)**; runs on PRs | `.github/workflows/codeql.yml` |
| L6 | Cucumber / .feature files | ABSENT (waived) | n/a |
| L7 | UAT lifecycle | ABSENT (waived) | n/a |

## Frameworks

- **Runtime**: Ruby 3.2 / 3.3 / 3.4; Rails 7.1+ (engine)
- **Tests**: RSpec, rspec-rails (declared in gemspec)
- **Coverage**: SimpleCov + simplecov-cobertura → Codecov
- **Linting**: RuboCop (+ rubocop-rails, rubocop-rspec)
- **Boundaries**: Packwerk
- **Security SAST**: brakeman + bundler-audit (Ruby-specific) + CodeQL `security-extended` (cross-method taint flows)

## Traceability

- `tests/RTM.md` — requirements traceability (council fixes + PRD reqs ↔ tests)
- `tests/PERSONAS.md` — personas (4) with per-persona flow coverage
- `tests/JOURNEYS.md` — journeys (4) with per-step layer mapping
- `000-docs/002-PP-PRD-product-requirements.md` — source PRD
- `000-docs/004-PP-UJRN-user-journey.md` — source journeys
- `000-docs/006-OD-STAT-status.md` — phase status mirror

## Last audit

| Field | Value |
|---|---|
| Date | 2026-05-31 (post-namespace-move re-audit) |
| Branch | `feat/role6-pr1-f2-audit-emission` |
| Grade | **A− (90/100)** — see `TEST_AUDIT.md` for the full snapshot |
| P0 gaps | **0** — L1/L2/L3 installed + CI-enforced; coverage gate, Codecov, CodeQL all live |
| P1 gaps | 2 (per-file coverage floor still commented out — now lift-able; mutation/property/CRAP waiver rationale stale — decision point fired) |
| P2 gaps | `spec/dummy/` absent (Role 8); TESTING.md policy-section drift flagged for engineer |
| Verified | 2988 examples / 0 failures; 98.29% line coverage; all 11 package.yml present; CodeQL on main; CODECOV_TOKEN set |
| Handoff | None — no infra gap; remaining P1 items are engineer-owned policy decisions |
| Prior audit | 2026-05-28 grade C (62/100), pre-namespace-move (PR #7, f3462eb) |
| Re-audit cadence | After Role 6/7 close the deferred behavior beads (F2/F3/F7/F8) + Role 8 lands `spec/dummy/` → lift L4 waiver + measure namespace-level coverage |

## Audit-harness installation (L0)

| State | Value |
|---|---|
| `@intentsolutions/audit-harness` (Node) | N/A (Ruby repo) |
| `intent-audit-harness` (PyPI) | N/A |
| `.audit-harness/` (vendored) | **Installed v1.1.4** at `.audit-harness/scripts/` |
| Wrapper | `scripts/audit-harness` (invoke as `scripts/audit-harness <command>`) |
| Hash manifest (`.harness-hash`) | **Initialized** 2026-05-29 — 0 files pinned (no Gherkin + no JS/Python architecture configs to auto-discover yet; populates as Role 4 lands per-namespace `package.yml` and any future `features/`) |

### Vendored install notes

- Upstream `install.sh` from `jeremylongshore/audit-harness` defaults to `v0.1.0` and contains a tarball-path bug (looks for `audit-harness-*` but the GitHub repo was renamed; tarballs unpack as `intent-audit-harness-X.Y.Z/`). Worked around manually by installing v1.1.4 with the corrected directory name. Tracked in user CLAUDE.md memory `audit-harness-npm-publish-gap-git-tags-v1`.
- Wrapper at `scripts/audit-harness` mirrors the Node CLI surface; commands work identically across language stacks.

## Local git hooks (L1)

| Hook | Source | Behavior | Bypass |
|---|---|---|---|
| `pre-commit` | `scripts/git-hooks/pre-commit` | RuboCop on staged Ruby files | `git commit --no-verify` |
| `commit-msg` | `scripts/git-hooks/commit-msg` | Conventional-commits regex | `git commit --no-verify` |
| `pre-push` | `scripts/git-hooks/pre-push` | RSpec smoke (spec/wild_spec.rb only — fast) | `git push --no-verify` |
| Installer | `scripts/install-hooks` | One-shot symlink installer; idempotent; supports `--uninstall` | — |

Hooks are committed in-repo (`scripts/git-hooks/`) so updates flow through PR review. No gem dependency on lefthook / pre-commit / husky was added (engineer policy: `wild.gemspec` not modified during this install).
