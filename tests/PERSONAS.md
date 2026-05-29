# Personas — wild

> Source: `000-docs/002-PP-PRD-product-requirements.md` § Personas + `000-docs/004-PP-UJRN-user-journey.md`.
> Per-persona flow coverage is computed from the journey graph in `tests/JOURNEYS.md`.

**Last rebuild:** 2026-05-28

## Coverage summary

| Persona | Key flows | Flows tested | Coverage | Status |
|---|---|---|---|---|
| Rails Tech Lead | 7 | 0 | 0% | Below threshold (P0 — stopwatch test fixture covers this in P2/P4) |
| MCP Consumer (non-Rails) | 5 | 0 | 0% | Below threshold |
| Security Reviewer | 6 | 0 | 0% | Below threshold |
| Maintainer (Jeremy) | 4 | 1 | 25% | Below threshold |
| **Total** | 22 | 1 | 5% | |

Coverage threshold: 80% per persona at v0.1.0 ship. Current 5% is expected
pre-Role-5 — Role 7 (`test-automator`) raises this as code lands per
`build-orchestration/roles/07-test-consolidator.md`.

---

## P1 — Rails Tech Lead (primary)

**Profile:** Senior Rails dev adopting `wild` for their app's AI-agent integration. Wants `bundle add wild && rails g wild:install` to just work.

**Success metric:** passes the five-minute stopwatch test (DHH non-negotiable).

| # | Key flow | Linked REQ | Status |
|---|---|---|---|
| 1 | `bundle add wild` resolves cleanly on Ruby 3.2/3.3/3.4 + Rails 7.1+ | REQ-001, FR-1 | Untested |
| 2 | `rails g wild:install` writes 3 config files + mounts engine | REQ-009, FR-2, F9 | Untested — generator stub only |
| 3 | Edit `Wild.configure` block via single nested-accessor file | REQ-002, F1 | Untested — Role 4 ships P1 |
| 4 | `bin/rails server` boots with engine mounted | REQ-001 | Untested |
| 5 | Connect Claude Code MCP → first `inspect_model_schema` call returns schema | REQ-008, FR-3 | Untested |
| 6 | Audit log shows one structured event for the gate decision | REQ-003, F2 | Untested — Role 6 ships P1 |
| 7 | End-to-end under 5 min wall-clock | REQ-011, Gate 4 stopwatch | Untested — Role 8 ships P2 |

**Persona owner test files (when written):**
- `spec/stopwatch/rails_tech_lead_spec.rb` (Role 8 P2 deliverable)
- `spec/engine/install_generator_spec.rb` (Role 8 P2)

---

## P2 — MCP Consumer (non-Rails)

**Profile:** Engineer using `wild`'s MCP servers via `gem install wild` without mounting the Rails engine. Wants the bin scripts to work standalone.

**Success metric:** `wild-mcp-introspection --help` works; MCP client connects; tool descriptions are versioned and reviewable.

| # | Key flow | Linked REQ | Status |
|---|---|---|---|
| 1 | `gem install wild` installs the gem + the two bin scripts | REQ-008 | Untested |
| 2 | `wild-mcp-introspection --help` shows flags (no Rails dependency loaded) | REQ-012 | Untested — Role 9 P2 |
| 3 | `wild-mcp-introspection --access-policy ./policy.yml` starts on stdio | REQ-008 | Untested |
| 4 | MCP client calls `list_allowed_models` discovery tool | REQ-008 + F7 | Untested — Role 9 P2 |
| 5 | Tool descriptions in `prompts/<tool>.md` are versioned + diffable | REQ-108, NFR-7 | Untested |

---

## P3 — Security Reviewer

**Profile:** Compliance / security lead auditing `wild` before their team adopts it.

**Success metric:** one SECURITY.md, one threat model, per-namespace threat surface, audit-trail completeness.

| # | Key flow | Linked REQ | Status |
|---|---|---|---|
| 1 | Land on README, see council-blessed Topology A statement | REQ-001 | n/a (doc check) |
| 2 | Read SECURITY.md — one disclosure path, severity SLA, per-namespace surface | (doc — landed in P0) | n/a (doc check) |
| 3 | Verify F2 audit-emission fix via `spec/wild/capability_gate/audit_liveness_spec.rb` | REQ-003, F2 | Untested — Role 6 P1 |
| 4 | Verify shared wildcard corpus matches identically in permission analyzer + capability gate | REQ-005, F4 | Untested — Role 4/6 P1 |
| 5 | Verify ADR-0001 + ADR-0002 explicit and discoverable | (doc — landed in P0) | n/a (doc check) |
| 6 | CodeQL `security-extended` findings triaged | (CodeQL workflow on PR #6) | Pending first CodeQL run |

---

## P4 — Maintainer (Jeremy)

**Profile:** The single signer; owns release pipeline + bead closure.

| # | Key flow | Linked REQ | Status |
|---|---|---|---|
| 1 | One CI run per PR (RSpec + RuboCop + Packwerk + brakeman + bundler-audit + Codecov + CodeQL) | NFR-2..6 | **Covered** — `spec/engine/version_spec.rb` exercises the test runner; CI workflows exist |
| 2 | One Release workflow (workflow_dispatch only); bumps version, builds gem, creates GitHub Release | REQ-011 | Untested — first fire is v0.1.0 cut |
| 3 | One bd workflow — `wild-rvv.*` epic + 13 council fix beads close with evidence | REQ-011 | Untested — closures land per role completions |
| 4 | One SECURITY.md disclosure path; triage clock starts on email | (P0 deliverable) | n/a (process) |

---

## Anti-personas (out of scope; do NOT design for)

| Anti-persona | Why |
|---|---|
| "Just wants one namespace, hates the others" | ADR-0002 governs extraction; until that fires, `Wild.config.<ns>.enabled = false` is the answer |
| "Wants to vendor the gem and patch capability_gate internals" | `# @api private` discipline + Packwerk boundaries reject this path |
| "Treats MCP tool descriptions as inline string literals" | Karpathy-mandated: versioned files only |
| "Treats test count as a quality metric" | F3 forbidden framing |
