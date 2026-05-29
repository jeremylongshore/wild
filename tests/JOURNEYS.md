# Journeys — wild

> Source: `000-docs/004-PP-UJRN-user-journey.md`. Each step is mapped to a 7-layer taxonomy test position. Severity = MoSCoW tier of linked REQ.

**Last rebuild:** 2026-05-28

## Coverage summary

| Journey | Steps | Steps tested | Status |
|---|---|---|---|
| J1 — Rails developer adoption (DHH stopwatch) | 11 | 0 | All untested — P0/P2 deliverables (Roles 8 + 9) |
| J2 — MCP consumer (non-Rails) | 5 | 0 | All untested — P2 (Role 9) |
| J3 — Security reviewer | 6 | 1 | One step covered (CodeQL on PR #6); rest P1 |
| J4 — Maintainer | 4 | 1 | One step covered (CI runs); rest pending v0.1.0 |
| **Total** | 26 | 2 | 8% |

---

## J1 — Rails developer adoption (the flagship — DHH stopwatch test)

| Step | Time budget | Layer | Test | Status | Severity |
|---|---|---|---|---|---|
| `rails new myapp --skip-bundle` | 0:00 | L4 (env scaffold; not under our control) | — | n/a | n/a |
| `cd myapp && bundle add wild` | 0:15 | L4 (dependency resolution) | `spec/stopwatch/` (Role 8) | Untested | **MUST (REQ-001)** |
| `bin/rails g wild:install` | 1:00 | L3 (generator) | `spec/engine/install_generator_spec.rb` (Role 8) | Untested | **MUST (REQ-009)** |
| Generator writes `config/initializers/wild.rb`, `access_policy.yml`, `capabilities.yml`; mounts engine | 1:30 | L3 (generator output spec) | (Role 8) | Untested | **MUST (REQ-009)** |
| Developer skims yaml configs; defaults are safe (read-only `User` introspection, no admin tools enabled) | 2:00 | L3 (default content assertion) | (Role 8) | Untested | **MUST (REQ-009)** |
| `bin/rails server` boots, engine mounts, no errors | 2:30 | L4 (engine integration) | `spec/dummy/` Rails app (Role 8 P2 prereq) | Untested | **MUST (REQ-001)** |
| Configure Claude Code MCP at `/wild/mcp/introspection` | 3:00 | (manual) | (n/a) | n/a | n/a |
| MCP call `inspect_model_schema(model: "User")` reaches `Wild::Introspection` → through `Wild::CapabilityGate` → audit-emitted | 3:30 | L4 (integration) + L3 (gate audit) | `spec/wild/introspection/`, `spec/wild/capability_gate/audit_liveness_spec.rb` | Untested | **MUST (REQ-003, REQ-008)** |
| Developer sees model schema response | 4:00 | L4 | (Role 9 P2) | Untested | **MUST (REQ-008)** |
| Developer checks `log/development.log` — one structured audit event | 4:30 | L3 (audit-liveness) | `spec/wild/capability_gate/audit_liveness_spec.rb` (Role 6 P1) | Untested | **MUST (REQ-003)** |
| Total wall-clock < 5 minutes | 5:00 | L7 stopwatch acceptance | `spec/stopwatch/stopwatch_spec.rb` (Role 8 P2 final + Gate 4 P4) | Untested | **MUST (REQ-011)** |

**Gate**: This journey IS Gate 4. Pass under 5 min wall-clock or v0.1.0 doesn't ship.

---

## J2 — MCP consumer (non-Rails)

| Step | Layer | Test | Status | Severity |
|---|---|---|---|---|
| `gem install wild` installs gem + bin scripts | L1 (publish) → L4 (install) | (post-release smoke) | Untested | MUST (REQ-008) |
| `wild-mcp-introspection --help` shows flags | L3 (bin script unit) | `spec/wild/introspection/cli_spec.rb` (Role 9 P2) | Untested | MUST (REQ-012) |
| `wild-mcp-introspection --access-policy ./policy.yml` starts on stdio | L4 (transport) | `spec/wild/introspection/mcp_transport_spec.rb` (Role 9) | Untested | MUST (REQ-008) |
| Consumer's MCP client calls tools; each description is loaded from `prompts/<tool>.md` | L3 (prompt loading) | (Role 9) | Untested | MUST (REQ-108) |
| Inspect prompt files (versioned, diffable) | L2 (file presence) | (Role 9 / fitness) | Untested | SHOULD |

---

## J3 — Security reviewer

| Step | Layer | Test | Status | Severity |
|---|---|---|---|---|
| Land on README; sees Topology A statement | L0 (doc) | (manual check) | n/a (doc) | MUST (REQ-001) |
| Read SECURITY.md — one disclosure path, severity SLAs, per-namespace surface | L0 (doc) | (P0 deliverable) | Covered (P0 commit) | MUST |
| Read `000-docs/003-AT-ARCH-architecture.md` § Audit trail | L0 (doc) | (P0 deliverable) | Covered (P0 commit) | MUST |
| Skim `spec/wild/capability_gate/audit_liveness_spec.rb` to verify F2 | L3 | (Role 6 P1) | Untested | **MUST (REQ-003)** |
| Read ADR-0001 + ADR-0002 | L0 (doc) | (P0 deliverable) | Covered (P0 commit) | MUST |
| **CodeQL findings triaged** | L5 | (PR #6 first run) | Pending CodeQL run | SHOULD |

---

## J4 — Maintainer (Jeremy)

| Step | Layer | Test | Status | Severity |
|---|---|---|---|---|
| One CI run per PR | L1 | `ci.yml`, RSpec test job (executes `spec/engine/version_spec.rb`) | **Covered** | MUST |
| One Release workflow (workflow_dispatch, gem build, GitHub Release) | L1 | First fire is v0.1.0 | Untested | MUST (REQ-011) |
| One bd workflow — all 13 council fix beads close with evidence | L0 (process) | (n/a — bead audit) | Pending | MUST (REQ-011) |
| One SECURITY.md disclosure triage clock | L0 (process) | n/a | n/a | MUST |

---

## Untested-step flag list (P0/P1/P2)

| Severity | Count | Examples |
|---|---|---|
| **P0** (MUST untested) | 13 | J1 steps 2-11; J2 step 1; J3 step 4 |
| P1 (SHOULD untested) | 5 | J2 step 5; J3 step 6; etc. |
| P2 (COULD untested) | 0 | (none — all COULDs are deferred to v0.2+) |

**Expected at this build phase.** Role 5 + Role 6 + Role 7 + Role 8 + Role 9 collectively raise this coverage as P1 + P2 land. Role 7 (`test-automator`) owns the test consolidation that closes most of these.

## Out-of-journey behaviors (tested in unit only, never in a journey)

| Behavior | Test | Status |
|---|---|---|
| `Wild.config` nested-accessor stub responds to arbitrary methods | `spec/engine/version_spec.rb` (passes when bundle installed) | Skeleton |
| `Wild::Error` base class is a `StandardError` subclass | (none yet — Role 5) | Untested |
| `lib/wild/version.rb` is a valid SemVer string | `spec/engine/version_spec.rb` | Covered |
