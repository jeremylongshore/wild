# CodeQL strategy for wild

**Author:** Jeremy Longshore
**Date:** 2026-05-28
**Status:** Approved baseline (v0.1.0 cycle)
**Companion files:** `.github/workflows/codeql.yml`, `.github/codeql/codeql-config.yml`

This document captures the three-tier CodeQL strategy chosen for this repo,
the rationale per choice, and the future custom-query-pack roadmap. It is the
durable record that survives session compaction — future Claude sessions or
contributors read this before changing the CodeQL config.

## TL;DR

- **One repo-local CodeQL workflow** + **one repo-local config file**, no
  org-level / account-level CodeQL config (GitHub doesn't offer that surface
  in the way Codecov does for personal-namespace repos).
- **Languages scanned:** `ruby` + `actions`. No JavaScript/Python/Go/Rust.
- **Query suite:** `security-extended` (default + Ruby taint queries beyond default).
  `security-and-quality` is OFF until end of P1 (would drown signal on stub code).
- **Triggers:** pull_request, push to main, weekly Sunday 04:17 UTC.
- **PR-blocking threshold:** critical + high severity during v0.1.0 cycle;
  tighten to medium and above post-v0.1.0.
- **Custom query packs:** none ship in this PR; ten future candidates listed
  in §C below for Intent Solutions-wide adoption.

---

## A. Global / default CodeQL standard

### The account-level question, answered plainly

GitHub does NOT expose an account-level (personal namespace) CodeQL global
YAML the way Codecov exposes account YAML. The closest mechanisms are:

| Mechanism | Available for `jeremylongshore` (personal)? | Status for IS use |
|---|---|---|
| Org-level default setup (GH Code Scanning) | Requires an organization with GHAS-eligible plan | N/A |
| **Reusable workflow** in `jeremylongshore/.github` | Yes — recommended | Roadmap item; not in this PR |
| Shared `.github/codeql/codeql-config.yml` template (copy-paste pattern) | Yes — practical today | Pattern documented in this doc |
| Repo-bootstrap script (CLI that scaffolds CodeQL into a repo) | Yes | Future Intent Solutions tooling |

**The practical Intent Solutions baseline today is the shared template + this
strategy doc.** When a `jeremylongshore/.github` repo lands, the workflow in
this repo collapses to:

```yaml
# .github/workflows/codeql.yml — future, reusable-workflow form
name: CodeQL
on:
  pull_request: { branches: [main] }
  push:         { branches: [main] }
  schedule:     [{ cron: "17 4 * * 0" }]

jobs:
  call-baseline:
    uses: jeremylongshore/.github/.github/workflows/codeql-base.yml@main
    permissions:
      contents:        read
      actions:         read
      security-events: write
      packages:        read
    with:
      languages: '[{"language":"ruby","build-mode":"none"},{"language":"actions","build-mode":"none"}]'
      config-file: .github/codeql/codeql-config.yml
```

For now the workflow is inlined so the repo is self-sufficient. Migration to
reusable is a 1-PR change later.

### Default CodeQL workflow shape (the IS baseline)

| Aspect | Default | Reasoning |
|---|---|---|
| Triggers | `pull_request` to default branch; `push` to default branch; weekly schedule | PR gate + post-merge sanity + scheduled run catches new queries since last code change |
| Schedule cron | `17 4 * * 0` (Sunday 04:17 UTC) | Offset from 0/15/30/45 minute spikes; weekly enough for the value, low cost |
| Permissions | `contents:read`, `actions:read`, `security-events:write`, `packages:read` | Minimum surface required to upload SARIF |
| Concurrency | grouped by workflow + ref, cancel-in-progress | Avoids parallel runs on rapid pushes |
| `timeout-minutes` | 30 | Generous for Ruby+Actions; raise if matrix grows |
| Strategy | Matrix on language with `fail-fast: false` | One language failure doesn't suppress others |
| Build mode | `none` for interpreted languages (Ruby, JS, Python, Actions) | No compilation step needed |
| Config file | `.github/codeql/codeql-config.yml` | Repo-specific drill-downs live here, NOT in the workflow |
| Category | `/language:${{ matrix.language }}` | Multi-language SARIF results sort cleanly in the Security tab |

### Default query suites

| Suite | Default state |
|---|---|
| `default` | Implicit baseline |
| `security-extended` | **ON** — adds Ruby taint queries beyond default |
| `security-and-quality` | OFF by default; opt-in per repo when codebase has stabilized |

### Default ignored paths (the common subset)

These are noisy or off-surface in every Intent Solutions repo regardless of
stack:

```
spec/**, test/**, tests/**, __tests__/**
coverage/**
tmp/**, log/**, pkg/**, build/**, dist/**
vendor/**, node_modules/**
.beads/**, .dolt/**, .audit-harness/**
docs/**, 000-docs/**
```

### Default PR behavior

Findings surface in the Files Changed → Code Scanning tab. **The global
default does NOT make them block-by-default.** Each repo decides which
severities block via branch protection. The wild repo's choice is §B below.

### Default permissions vs Codecov / other CI gates

| Gate | Workflow | What it covers |
|---|---|---|
| CI (RuboCop, Packwerk, brakeman, bundler-audit, RSpec, Codecov upload) | `.github/workflows/ci.yml` | Style, namespace boundaries, Ruby SAST, gem CVEs, tests, coverage |
| CodeQL | `.github/workflows/codeql.yml` | Cross-method taint flows, dynamic dispatch risks, Actions supply-chain issues, language-agnostic data-flow |
| Release | `.github/workflows/release.yml` | Tag + GitHub Release + gem build; workflow_dispatch only |

CodeQL is independent of Codecov. They produce different artifacts (SARIF vs
coverage reports) consumed by different surfaces (Security tab vs codecov.io).

### What MUST stay repo-specific

The global default fixes the workflow shape only. Each repo decides:

- Language matrix
- Path includes / excludes (which directories are production surface)
- Whether `security-and-quality` is ON
- Severity-to-block mapping
- Custom query packs
- Whether to inline the workflow (self-sufficient) or reference a reusable

---

## B. Repo-specific drill-down for `jeremylongshore/wild`

### Languages

`ruby` and `actions`. There is no JavaScript, Python, Go, or other compiled
language in this repo. If a future namespace adds one (unlikely per
ADR-0001), update the matrix.

### Build mode

`none` for both. Ruby is interpreted; `actions` queries scan YAML.

### Paths included

```
lib/wild/**
lib/generators/**
lib/wild.rb
bin/wild-mcp-introspection
bin/wild-mcp-admin
.github/workflows/**
```

The actual production-surface code. When Role 5 lands the ten old gems'
`lib/` trees under `lib/wild/<namespace>/`, the wildcard captures them — no
config change required.

### Paths ignored

| Path | Why ignored |
|---|---|
| `spec/**` | Test code, fixtures, helpers, dummy Rails app |
| `000-docs/**` | Markdown documentation |
| `prompts/**` | Versioned MCP tool descriptions (Karpathy seam) |
| `schemas/**` | Schemas-as-data YAML (Hickey seam) |
| `coverage/**` | SimpleCov output |
| `tmp/`, `log/`, `pkg/` | Build artifacts |
| `vendor/**` | Vendored gems |
| `node_modules/**` | Defensive — not used today but cheap to ignore |
| `.beads/**`, `.dolt/**` | bd database/exports |
| `.audit-harness/**` | Vendored test harness (when `/implement-tests` adds it) |
| `bin/setup`, `bin/console` | Dev shell scripts; out of MCP boundary |

### `security-extended` ON, `security-and-quality` OFF

Council rev2 prioritizes security correctness — see §F2 (audit-blind paths),
§F4 (cross-namespace contract drift), §F5 (skillops claims unsupported), and
the entire MIN-Armstrong dissent on error hierarchy. `security-extended`
catches Ruby taint flows that brakeman misses (cross-method, dynamic
dispatch, lambda boundaries).

`security-and-quality` is deferred until end of P1 because:

- Namespace dirs are still `.keep` placeholders; quality queries fire on
  generated/stub code and drown the security signal
- Beck F3 mandate ("judgment tests, not vanity counts") applies to CodeQL
  findings too — better to triage 20 high-signal findings than 200 mixed
- Re-enable at the Gate 2 sign-off (end of P1) and triage the first wave
  before P2 begins

### PR-blocking thresholds

| Severity | v0.1.0 cycle | Post-v0.1.0 |
|---|---|---|
| critical | **Block** | Block |
| high | **Block** | Block |
| medium | Informational | **Block** |
| low | Informational | Informational |
| note | Informational | Informational |

Branch protection on `main` will reflect this when v0.1.0 ships. During the
build the default is "no block" since the repo has no consumers yet —
findings are still surfaced and triaged via beads.

### Review labels that trigger deeper review

| Label | Triggers |
|---|---|
| `security-review` | `backend-security-coder` agent review on the PR |
| `capability-gate` | Specific `joe-armstrong-reviewer` review against F2 |
| `mcp-transport` | `andrej-karpathy-reviewer` review against MIN-Karpathy |
| `release-pipeline` | `architect-reviewer` review against Gate 4 |
| `boundaries` | `martin-fowler-reviewer` review against ADR-0001 |

Labels are filed under the bead labels of the same names (`bd list --label
security-review` queries the corresponding tracked work).

---

## C. Future custom query pack candidates

Ranked by leverage for the wild ecosystem (and Intent Solutions-wide).
None ships in this PR. Each is a future PR with a designed query, fixtures,
and at least one positive + one negative test case in CodeQL's testing harness.

### 1. `rb/wild/audit-emission-required` — HIGHEST LEVERAGE

**What:** Every `rescue` clause in `lib/wild/capability_gate/` must, within
N statements (default 3), either re-raise the exception OR call a method
whose name matches `emit_audit*` / `audit_event*` / `log_decision*`.

**Why:** Directly enforces F2 council fix at AST level, not just at test time.
Catches "I added a new rescue path and forgot the audit event" before it
ships. The most-leveraged query in the entire ecosystem because F2 is the
most-leveraged council finding.

**Ship after:** Role 6 lands the F2 fix (P1, sub-bead `wild-rvv.4.1`).

### 2. `rb/wild/mcp-input-validation`

**What:** Every public method in `Wild::Introspection` or `Wild::AdminTools`
reachable from `bin/wild-mcp-*` must validate input types at the transport
boundary (presence of a guard clause, `Wild::Schema.validate!`, or equivalent).

**Why:** Catches "we forgot to check the MCP JSON shape" before it ships.
MCP transport is the highest-touch external surface.

**Ship after:** Role 9 lands MCP bin scripts (P2).

### 3. `rb/wild/capability-gate-required`

**What:** Every public method on `Wild::AdminTools` must, on at least one
taint path from `bin/wild-mcp-admin` entry, pass through
`Wild::CapabilityGate#evaluate`.

**Why:** Catches admin tools that accidentally became un-gated. Highest
single-incident-cost vulnerability class for this gem.

**Ship after:** Role 6 + Role 5 stabilize the gate + admin_tools.

### 4. `rb/wild/no-dynamic-eval-outside-config`

**What:** `eval` / `instance_eval` / `class_eval` outside an approved
allowlist (`lib/wild/configuration.rb`, vendored Rails internals) must be
explicitly justified with a `# @api private` comment AND an ADR reference.

**Why:** Matches the architecture's dynamic-method-call discipline (Role 4
replaces the OpenStruct stub with typed accessors; subsequent dynamic
patterns need explicit review).

### 5. `rb/wild/telemetry-no-pii-at-info`

**What:** No method named matching PII patterns (`email`, `phone`,
`address`, `ssn`, `tax_id`, `*_token`, `*_secret`) is passed as a positional/
keyword arg to `Wild.config.audit_logger.info` / `Rails.logger.info`.

**Why:** Privacy gate for telemetry. Council rev2 preserved Kleppmann's
dissent specifically around honest framing of what telemetry collects.

**Ship after:** Role 5 + Role 4 land telemetry consolidation (P1).

### 6. `actions/wild/no-pull-request-target`

**What:** No workflow uses `pull_request_target` event.

**Why:** Currently you don't; this prevents accidental regression. Common
GitHub-Actions supply-chain footgun.

### 7. `actions/wild/pinned-action-shas`

**What:** All `uses:` lines reference a SHA, not a version tag.

**Why:** Supply chain. Currently `actions/checkout@v4` is tag-pinned. The
counter-argument is that Dependabot keeps tags fresh and SHA pinning makes
PR diffs noisier. Default: SHA-pin only the third-party actions (Codecov,
ruby-setup, codeql-action), keep first-party (`actions/checkout`,
`actions/cache`) on tags.

### 8. `rb/wild/release-no-bypass`

**What:** `release.yml` must run RSpec, RuboCop, Packwerk in the
"verify readiness" step before tag creation.

**Why:** Catches future change that removes a gate from the release path.

### 9. `rb/wild/hardcoded-secret-shape`

**What:** String literals matching known token shapes (`ghp_*`, `xoxb-*`,
`sk-*`, `npm_*`, AWS access keys, etc.) outside test fixtures.

**Why:** Defense in depth alongside GitHub secret scanning.

### 10. `rb/wild/filesystem-write-outside-approved`

**What:** `File.open(path, "w"/"a")`, `FileUtils.cp`, etc. anywhere except
`lib/generators/**` and explicitly approved telemetry collector paths.

**Why:** Catches an MCP admin tool that accidentally writes to disk outside
its sandbox.

---

## Rollout plan

| When | What |
|---|---|
| This PR (`feat/codeql-baseline`) | Workflow + config + this doc + bd bead |
| First CodeQL run (post-merge) | Triage first batch of findings; file each as a bead under affected namespace's epic |
| End of P1 | Flip `security-and-quality` to ON; triage second wave |
| End of P2 | Ship custom query #1 (`audit-emission-required`) — depends on F2 fix landing first |
| End of P3 | Ship custom query #2 (`mcp-input-validation`) — depends on Role 9 MCP bin scripts |
| Pre-v0.1.0 (Gate 4) | Branch protection on `main` reflects PR-blocking thresholds in §B |
| Post-v0.1.0 | Migrate to reusable workflow in `jeremylongshore/.github` |

## Out of scope for this strategy

- Semgrep, SonarCloud, other SAST tools. Not adopting; brakeman + bundler-audit
  + CodeQL is the chosen SAST stack for this repo
- Trivy or other container scanners. No container build today
- License scanning. Out of scope for v0.1.0; revisit when distribution grows
- Threat modeling document. SECURITY.md + per-namespace `THREAT_MODEL.md` files
  (P1 deliverable) cover the human-review surface

## Source documents

- Council rev2 verdict: `/home/jeremy/000-projects/wild/wild-rails-ai-ops/000-docs/013-AT-AUDT-thinker-council-verdict-rev2-2026-05-29.md`
- DHH migration plan: `/home/jeremy/000-projects/wild/wild-rails-ai-ops/000-docs/010-AT-VRDT-dhh-2026-05-29.md`
- ADR-0001 topology: `000-docs/adr/ADR-0001-topology.md`
- ADR-0002 namespace extraction: `000-docs/adr/ADR-0002-namespace-extraction-policy.md`
- Architecture: `000-docs/003-AT-ARCH-architecture.md`
- Technical spec (CI shape): `000-docs/005-AT-SPEC-technical-spec.md`
- Build orchestration: `/home/jeremy/000-projects/wild/build-orchestration/`
- GitHub CodeQL docs: https://docs.github.com/en/code-security/code-scanning
- CodeQL Ruby support: https://codeql.github.com/docs/codeql-language-guides/codeql-library-for-ruby/
