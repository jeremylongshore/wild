# 009-PP-PLAN — Strategic review and fix wave on the wild engine gem (2026-08-25)

> **What this is and why it matters.** `wild` is a Rails engine gem that folds ten previously
> separate `wild-*` gems into one package with ten `Wild::*` namespaces (introspection, admin
> tools, capability gate, telemetry, hooks, analyzers, skillops). The consolidation build ran
> as an 11-role, 5-phase plan and paused on 2026-06-02, mid-phase P1 at Role 6, with no commits
> since. Before anyone resumes the build or shows the gem to outside eyes (Omarchy / Rails
> community attention makes an embarrassing defect expensive), the whole repo gets one
> end-to-end review with current multi-agent capability: find what is actually wrong, verify
> it adversarially, fix it in small reviewable PRs, and reconcile every status page to what
> shipped. This document is the plan of record for that interlude. It runs between Role 6 and
> Role 7 and does not re-litigate the locked decisions (ADR-0001..0003, the 11 locked
> decisions in `build-orchestration/README.md`).

- **Epic:** "Run a strategic review and fix wave on the wild engine gem before resuming the build" (top-level, not under the consolidation epic it audits)
- **GitHub:** issue on `jeremylongshore/wild` (linked from the epic bead notes)
- **Author:** Jeremy Longshore
- **Status:** COMPLETE (2026-08-26). Review record: [010-RA-REVW](010-RA-REVW-review-wave-findings-and-bead-docket-2026-08-25.md); closeout: [011-AA-AACR](011-AA-AACR-strategic-review-and-fix-wave-2026-08-26.md).
- **Pattern sources:** intent-os `039-DR-STND` (epic documentation + AAR), `064-DR-STND §5`, `000-AA-TMPL`; intent-eval-lab `051-AA-AACR` + `051a` data.json (review-wave prototype), trimmed to gem scale.

## 1. Where the build stopped (verified 2026-08-25, not from stale docs)

| Fact | Evidence |
|---|---|
| Last human commit `265546d` 2026-06-02; last commit on main `f18b86c` 2026-06-04 (#43, vendored audit-harness 1.1.5) | `git log` |
| Roles 4 + 5 complete (all 10 namespaces moved, PRs #20–31); Role 6 landed #32–37, #40–42; F2 epic closed (#41 emit-time validator, #42 Gate-rescue contract) | `git log`, `bd show wild-rvv.4.1` |
| Council fixes fully closed: F1, F2, F4, MIN-Armstrong (4 of 13). STATUS.md still says F2 in progress (3 of 13) | `build-orchestration/STATUS.md` dated 2026-06-01 |
| F1's own close criterion (`grep -r 'class Configuration' lib` → 0) now returns 3 | `rg 'class Configuration' lib` |
| Suite red on main: 3076 examples, 7 failures. 6 = `spec/wild/telemetry/collector/store/retention_manager_spec.rb:27-34` hardcodes a `2026-03-19` "recent" fixture that has aged past the 90-day window. 1 = `spec/wild/analyzers/permission/adversarial/edge_cases_spec.rb:33-47` asserts `elapsed < 5.0` (a wall-clock perf bound, fails under load; NOT order-dependent as the workspace CLAUDE.md said) | local `bundle exec rspec` |
| CI Lint red on all 3 Dependabot PRs (#44, #45, #46): `Gemfile.lock` untracked, so CI resolves RuboCop 1.88 with new cops. 4 of 6 new offenses are `Style/ArrayIntersect` false positives whose autocorrect would break code (`admin_tools/audit/parameter_sanitizer.rb:39,41`, `hooks/audit/sanitizer.rb:71,73`) | `gh pr checks`, local rubocop 1.88 |
| `main` has no branch protection; "required checks are the gate" is aspirational | `gh api .../branches/main/protection` → 404 |
| Packwerk + brakeman fail identically locally and in CI (no Rails app, no `spec/dummy/`); ADR-0003 boundary enforced only in prose; `release.yml` cannot pass | `ci.yml` continue-on-error lanes |
| Showcase-fatal stubs: `bin/wild-mcp-*` `exit 1` yet listed in `spec.executables`; install generator is a stub; README claims a `wild` CLI that does not exist, claims old repos archived, claims `prompts/` ships | README, gemspec, `bin/` |
| Security open door: `lib/wild/introspection/identity/capability_gate.rb:38-43` grants every authenticated caller full capability (T4→T3 gate bypassed) | source read |
| Beads: 50 total, 14 closed, 6 in_progress, 30 open. Open P0s: `wild-rvv.3.1`, `wild-rvv.7.1`, `wild-rvv.8.1` | `bd stats`, `bd list` |

## 2. Scope and non-goals

**In scope:** the `jeremylongshore/wild` gem only. Every namespace, the engine surface, CI, tests, docs, and all 36 non-closed beads. Mode: review + fix. Showcase is decided after the findings are in (Stage 4), not before.

**Out of scope (every review prompt declares these):** the old ten `wild-*` repos (frozen; archive at P4), the umbrella `intent-solutions-io/wild-rails-ai-ops` (Role 11 only), Omarchy (no code link to wild), re-litigating ADR-0001..0003 or the 11 locked decisions, Role 7–11 feature work (generator, `prompts/`, MCP bin wiring, plugin, v0.1.0). Any feature ask surfaced by the review becomes a bead, not a PR.

## 3. The four stages

### Stage 0: bead tree + plan doc
Hand-rolled bead tree (§4), GH issues at cluster granularity, this document, `000-INDEX.md`, the AAR template copy, the untracked interlude briefing `build-orchestration/roles/06b-strategic-review-interlude.md`.

### Stage 1: pre-flight (three PRs, merge order B → A → C)
- **PR B `chore/ci-lockfile-lint`**: commit `Gemfile.lock` (conservative bump of `mcp rubocop rubocop-rails rubocop-rspec`), fix the 6 lint offenses under the locked RuboCop (autocorrect the 2 `RSpec/MatchWithSimpleRegex`; inline-disable the 4 `Style/ArrayIntersect` false positives with a reason; de-dup of those sanitizer files stays with bead `wild-rvv.6.2`), add a `ci-ok` fan-in job (`needs: [lint, security, test]`; packwerk `boundary` excluded until `spec/dummy/` exists). After merge: branch protection on `main` requiring `ci-ok` + CodeQL.
- **PR A `fix/test-wall-clock`**: retention fixtures computed relative to `Time.now.utc` (same pattern the file already uses at lines 96–104); drop the `elapsed < 5.0` assertion and keep the report-shape assertions; note the ~3s for 500×200 as a P2 review input. Verify on three seeds.
- **Dependabot**: rebase + auto-merge #44 (codecov-action 7) and #45 (checkout 7) after B. Close #46 (`mcp >= 0.8, < 2.0` would advertise an untested 1.x line; the servers call `MCP::Server.new`, `MCP::Tool`, `MCP::Tool::Response`) with a P2 bead to evaluate 1.x on a branch.
- **PR C `docs/truth-0.0.1`**: README status block (works / not yet), delete the phantom `bundle exec wild …` block, MCP servers under "Planned", fix the archived-repos claim, docs table via `000-INDEX.md`; gemspec drops `spec.executables` until the bins are real; delete root `schemas/` (`.keep` only; real schemas live at `lib/wild/schemas/`) and its `codecov.yml` ignore; 006 status + STATUS.md + workspace CLAUDE.md §10/§13 reconciled; CHANGELOG bullets; PR template extended to the full lane.
- Gate before Stage 2: `/validate-consistency` deterministic drift = 0, then `/sitrep`.

### Stage 2: the review wave (Workflow, ~20–23 agents)
Pre-computed `facts.json` handed to every lane (base SHA, the 7 known failures and their fix, F1 regression, empty `spec/engine/`, 0 `@api private` vs `enforce_privacy: true`, `Collector::StorageError` never raised, `Hooks::McpServer::ToolHandler.wrap` + `Hooks::Audit` unconsumed by T4, `wild-rvv.7.2` cites a nonexistent file, retention purge rewrites outside the store mutex, nonce wall-clock vs rate-limiter monotonic, all YAML via `safe_load`, packwerk/brakeman need a Rails app, per-namespace counts, the 36 bead IDs, the council ledger).

Twelve read-only lanes: L01 hooks (Armstrong), L02 telemetry/collector (Kleppmann), L03 telemetry/pipeline (code-reviewer), L04 telemetry/analysis (Hickey), L05 analyzers/permission (Fowler), L06 analyzers/test_flakes (Beck), L07 skillops (Torvalds), L08 capability_gate (security-auditor), L09 introspection (Thompson), L10 admin_tools (security-auditor), X1 engine/public surface (DHH, fallback Fowler), X2 boundaries/CI/tests (Beck). Findings carry stable IDs `f-<lane>-<n>`, severity P0–P3, file + lines, claim, trigger, evidence, a repro that starts with an allowed read-only command, a fix sketch, related beads/council fix/ADR, confidence.

A scripted evidence gate (no agent) enforces ID pattern, path + line spec, repro prefix, claim length; failures are downgraded to P3 with a reason, never deleted; same-file overlapping findings are deduped across lanes. Every P0/P1 goes to three refuters with distinct lenses (does the code do what is claimed; is it reachable from a real entry point; does the repro literally run). Majority rule; ties are listed for hand-check. One spot-verifier over P2/P3 may promote. Three `beads-guru` chunks disposition all 36 beads (`keep | re-scope | close-now | duplicate | needs-decision`) with evidence; the merge asserts every ID exactly once and `unaudited = 0`. One synthesizer writes `010-RA-REVW-…` + `010a-…-data.json` (findings funnel, 12-row namespace health, bead outcomes, the 13-row council-fix ledger delta, proposed fix clusters, decisions needed, process lessons).

Dispositions are applied by hand afterwards: close-now → duplicate → re-scope → needs-decision (note only), one op per command, JSONL verified after each, never `--force` reflexively, the 6 in_progress move-epics stay in_progress.

### Stage 3: fix wave
Cluster confirmed findings by Packwerk package × severity band; a P0 always gets its own PR; cross-namespace seam fixes cluster under the provider (lower tier). Order: P0s tier-up (T1 hooks/telemetry → T2 → T3 capability_gate → T4 introspection/admin_tools), then P1s. Hard constraints: `wild-rvv.6.2` (Hooks::Audit) before admin_tools audit fixes; `wild-rvv.3.1` + `wild-u16` (engine `after_initialize` wiring) before any T4 fix that assumes resolved config; a `spec/dummy/` PR (so packwerk, brakeman, and `release.yml` become real and `boundary` joins `ci-ok`; honest fallback = remove the two lanes and say so in STATUS) before packwerk-dependent fixes. Branch `fix/<pkg>-<f-id>`, ≤ ~400 non-spec lines / ≤ 10 non-spec files. Paired diff-verifier = `/code-review high`; T3/T4 and any `*/audit/` PR also gets `/security-review`. Merge via `gh pr merge --squash --auto` gated on `ci-ok` + CodeQL; PR body carries finding IDs, before/after repro, verifier verdict, CI run URL. Stubs (generator, `prompts/`, MCP bin wiring) stay P2 feature work outside this wave.

### Stage 4: close-out
`011-AA-AACR-…` from the template (9 sections), 010 flipped to FINAL, truth pass over CHANGELOG / 006 / STATUS.md / README / workspace CLAUDE.md, `/audit-tests` once, `/validate-consistency` again, E4 children closed via `bd-sync close`, E0 closed with `--also-close-gh`, and the showcase decision recorded as a decision bead + AAR §9 paragraph.

## 4. Bead tree

```
E0 epic  Run a strategic review and fix wave on the wild engine gem before resuming the build
 E1 epic  Restore a green baseline before the review starts
   E1.1 bug  Compute the retention spec fixtures relative to now so they stop aging past the window
   E1.2 bug  Drop the wall-clock bound from the permission scale spec and keep it as a shape test
   E1.3 task Commit Gemfile.lock, fix lint under the locked RuboCop, and add the ci-ok fan-in job
   E1.4 task Triage the three open Dependabot PRs and merge or close each with a stated reason
   E1.5 task Make the README, gemspec, and both status pages say what ships today
   E1.6 task File the review-wave plan, the docs index, the AAR template, and the full-lane PR template
 E2 epic  Review every namespace and disposition every open bead
   E2.1 task Run the twelve-lane review panel and record findings with stable IDs
   E2.2 task Adversarially verify every P0 and P1 finding against main before any fix is scheduled
   E2.3 task Audit all thirty-six open and in-progress beads and record a disposition with evidence
   E2.4 task Apply the bead dispositions one at a time and verify the exported state after each
   E2.5 task File the review record and its companion data file
 E3 epic  Fix what the review found, one cluster per branch
   E3.a..n epic  "Fix the <namespace> findings from the review: <theme>"  (hand-rolled only after E2.2)
 E4 epic  Close out the review wave with the after-action report and reconciled status
   E4.1 task Write the after-action report for the review wave
   E4.2 task Reconcile changelog, status pages, README, and workspace CLAUDE.md to what shipped
   E4.3 decision Decide whether and how to showcase wild now that the findings are in
```

Bead IDs are command handles only; the titles above are how the work is referred to. GH issues exist for E0, E1, E2, and each E3 cluster; task beads live under their parent.

## 5. Evidence bar

- A finding is not a finding without file + lines + a repro that starts with a read-only command. Gate-failed findings are downgraded, never deleted.
- A P0/P1 is scheduled for a fix only after majority confirmation by three independent refuters.
- A bead closes only with `bd-sync close --reason "<PR + SHA + repro + verifier line>"`; batch closes are forbidden (rapid-write race); the exported JSONL is checked after every op.
- A status page claim that cannot be traced to `git log`, `bd show`, `gh`, or a local run is removed, not repeated.

## 6. Documents produced

| Doc | Stage | Purpose |
|---|---|---|
| `000-INDEX.md` | 0 | Docs site-map |
| `000-AA-TMPL-after-action-report.md` | 0 | Byte-identical copy of the intent-os canonical AAR template |
| `009-PP-PLAN-…` (this) | 0 | Plan of record |
| `010-RA-REVW-…` + `010a-…-data.json` | 2 | Review record + machine-readable findings/dispositions |
| `011-AA-AACR-…` | 4 | After-action report |
| `build-orchestration/roles/06b-strategic-review-interlude.md` (untracked) | 0 | Role-briefing shape pointer for the interlude |

## 7. Risks

| Risk | Mitigation |
|---|---|
| Review lanes rediscover the known failures | `facts.json` + explicit out-of-scope list in every prompt |
| Agent false claims | scripted evidence gate + three-lens refute |
| Bead rapid-write race silently drops state | one op per command, `bd export` between, JSONL verified |
| Scope creep into Role 7/8 feature work | stubs policy; any feature ask becomes a bead |
| Docs drift again during the wave | E4.2 truth pass is the last PR |
| Branch protection + lockfile are policy changes | called out for approval before applying |

## 8. Definition of done

- `origin/main`: `ci-ok` + CodeQL required and green on the last 3 runs; `bundle exec rspec` 0 failures on 3 seeds locally; RuboCop 0 offenses at the locked version; `Gemfile.lock` committed; #44/#45 merged, #46 closed with a bead.
- Packwerk + brakeman blocking with `spec/dummy/` (0 violations / warnings, or waived with reason), or removed with a STATUS line. No permanently-red informational lane.
- Codecov ≥ thresholds; `minimum_coverage_by_file 75` on, or offenders beaded.
- Every confirmed P0/P1: closed with PR + SHA + repro + verifier line, or open with a one-line deferral and priority; bead counts reconcile to the ledger; `unaudited: 0`.
- README truthful (no phantom CLI, no shipped stubs, no archived-repos claim); `/validate-consistency` deterministic = 0.
- 009 / 010 / 010a / 011 filed; `000-INDEX.md` present; STATUS + 006 + workspace CLAUDE.md agree and are dated; CHANGELOG current.
- E0 closed via `bd-sync close --also-close-gh`; showcase decision recorded.

## 9. References

- `build-orchestration/{README,STATUS}.md`, `build-orchestration/fixes/13-council-fixes.md` (workspace, untracked)
- `000-docs/adr/ADR-000{1,2,3}-*.md`, `000-docs/006-OD-STAT-status.md`, `000-docs/008-AT-AUDT-pre-move-coupling-survey.md`
- Council verdict: `wild-rails-ai-ops/000-docs/013-AT-AUDT-thinker-council-verdict-rev2-2026-05-29.md`
- Pattern sources: `~/000-projects/intent-os/000-docs/{039-DR-STND,064-DR-STND,000-AA-TMPL}*.md`; `~/000-projects/intent-eval-platform/intent-eval-lab/000-docs/051{,a}-AA-AACR-umbrella-review-and-fix-wave-2026-06-11.*`
