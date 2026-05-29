# Testing policy — wild

> Engineer-owned policy file. AI may update observational sections (## Installed gates, ## Frameworks, ## Last audit, ## Traceability) but not policy sections (## Classification, ## Thresholds, ## Waived layers, ## Compliance overlay).

**Last audit:** 2026-05-28 (P0 — pre-namespace-move state)
**Policy hash-pin:** not yet initialized (fresh repo)

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
| L1 | Pre-commit hooks | **ABSENT** | (gap; see `TEST_AUDIT.md`) |
| L1 | Dependabot | Installed | `.github/dependabot.yml` |
| L2 | RuboCop (+ rails + rspec cops) | Installed, CI-enforced | `.rubocop.yml`, `ci.yml lint` job |
| L2 | Packwerk (namespace boundary) | Installed, CI-enforced; per-namespace `package.yml` ABSENT (Role 4 deliverable in P1) | `packwerk.yml`, `ci.yml boundary` job |
| L2 | brakeman | Installed, CI-enforced | gemspec dev dep, `ci.yml security` job |
| L2 | bundler-audit | Installed, CI-enforced | gemspec dev dep, `ci.yml security` job |
| L3 | RSpec | Installed (one real spec: `spec/engine/version_spec.rb`); per-namespace specs LAND in P1 | `spec/spec_helper.rb`, `.rspec`, `ci.yml test` matrix |
| L3 | SimpleCov + Cobertura | Installed (gated by `COVERAGE=1`) | `spec/spec_helper.rb` |
| L3 | Codecov upload | Installed; **`CODECOV_TOKEN` secret missing** | `ci.yml test` job, `codecov.yml` |
| L4 | spec/dummy/ Rails app | ABSENT | (gap — P2) |
| L5 | CodeQL (`security-extended`) | Installed on PR #6 | `.github/workflows/codeql.yml` |
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
| Date | 2026-05-28 |
| Branch | `feat/test-baseline` |
| Grade | C (62/100) — see `TEST_AUDIT.md` |
| P0 gaps | 3 |
| P1 gaps | 6 |
| Handoff to `/implement-tests` | recommended scope: L0 harness install + L1 git hooks + tests/ scaffolds; defer L3/L4/L5/L6/L7 expansion until Role 5 lands code |

## Audit-harness installation (L0)

| State | Value |
|---|---|
| `@intentsolutions/audit-harness` (Node) | N/A (Ruby repo) |
| `intent-audit-harness` (PyPI) | N/A |
| `.audit-harness/` (vendored) | **ABSENT** — install via `curl -sSL https://raw.githubusercontent.com/jeremylongshore/audit-harness/main/install.sh \| bash` |
| Hash manifest (`.harness-hash`) | **ABSENT** — initialize after engineer-reviewed first edit of policy sections |
