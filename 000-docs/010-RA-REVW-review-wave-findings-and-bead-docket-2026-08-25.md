# 010-RA-REVW: Review wave findings and bead docket for the wild engine gem (2026-08-25)

| Field | Value |
| --- | --- |
| **Doc** | `010-RA-REVW-review-wave-findings-and-bead-docket-2026-08-25.md` |
| **Date** | 2026-08-25 |
| **Status** | DRAFT (flips to FINAL at Stage 4 close-out, per `009-PP-PLAN` section 3) |
| **Scope** | `jeremylongshore/wild` only: 10 namespaces, the engine surface, CI, tests, docs, all 36 non-closed beads |
| **Base SHA** | `339453f` (main after PRs #51, #52, #53/#55 merged) |
| **Run id** | `wild-review-wave-2026-08-25` |
| **Companion** | `010a-RA-REVW-review-wave-findings-and-bead-docket-2026-08-25-data.json` (machine-readable: per-lane results, every finding with its votes, the full bead docket) |
| **Plan of record** | `000-docs/009-PP-PLAN-strategic-review-and-fix-wave-2026-08-25.md` |

---

`wild` is a Ruby on Rails engine gem. It folds ten previously separate `wild-*` gems into one package with ten `Wild::*` namespaces: safe database introspection for AI agents, administrative tools behind a confirmation flow, a capability gate that decides what a caller may do and writes an audit record for every decision, a telemetry collector, pipeline and analysis tier, a shared hooks substrate, two analyzers (permission model and test flakiness), and a skill registry. The consolidation build paused on 2026-06-02 mid-phase, with roughly half the planned roles done. Before anyone resumes that build, this review wave read every namespace with one dedicated reviewing agent per namespace, checked every high-severity claim with three independent verifiers, and audited every open task in the tracker against what the code actually does today. This document is the record of what that wave found: which findings survived verification, how healthy each namespace is, what happens to each open bead, where the project's own status ledger disagrees with the code, and what the fix wave that follows should do first. Nothing in it re-litigates the locked architecture decisions (ADR-0001 through ADR-0003); every feature ask surfaced here becomes a bead, not a PR.

## 1. What ran

One orchestrated workflow, run id `wild-review-wave-2026-08-25`, against `main` at `339453f`. Verifiers observed that the worktree HEAD had advanced to `397c5e2` (four chore commits: Dependabot merges and bead closes) during the wave; every verifier confirmed `lib/` and `spec/` were byte-identical to the base SHA for the files they examined.

**Agent shape.** 12 read-only review lanes, one per namespace or cross-cutting surface, each seeded with the same `facts.json` (base SHA, the seven known-and-already-fixed failures, the F1 regression, the empty `spec/engine/`, the unconsumed hooks substrate, the phantom bead paths, the retention-purge race, the nonce-vs-limiter clock split, the YAML safe-load fact, the packwerk/brakeman inertness, per-namespace counts, the 36 bead ids, the 13-row council ledger, and an explicit out-of-scope list). Then a scripted evidence gate (no agent), then three refuter lenses over every surviving P0/P1, one spot-verifier over the P2/P3 tail, three bead-auditor chunks over all 36 open and in-progress beads, and one synthesizer (this document). No lane failed.

**Lanes and lens design.** Each lane was given a named reviewer persona from the thinker council so the lens stayed consistent with the council finding it was checking.

| Lane | Surface | Tier | Lens persona | Files / LOC / spec files | Raw findings |
| --- | --- | --- | --- | --- | --- |
| L01 | `lib/wild/hooks` | T1 | Armstrong (error isolation) | 21 / 1320 / 22 | 5 |
| L02 | `lib/wild/telemetry/collector` | T1 | Kleppmann (durability) | 13 / 907 / 17 | 5 |
| L03 | `lib/wild/telemetry/pipeline` | T2 | code-reviewer | 16 / 1193 / 19 | 6 |
| L04 | `lib/wild/telemetry/analysis` | T2 | Hickey (decomplect) | 25 / 1197 / 26 | 5 |
| L05 | `lib/wild/analyzers/permission` | T2 | Fowler (refactoring) | 17 / 973 / 23 | 6 |
| L06 | `lib/wild/analyzers/test_flakes` | T2 | Beck (test discipline) | 21 / 1653 / 24 | 6 |
| L07 | `lib/wild/skillops` | T2 | Torvalds (honest surface) | 19 / 1069 / 23 | 6 |
| L08 | `lib/wild/capability_gate` | T3 | security-auditor | 18 / 1368 / 20 | 14 |
| L09 | `lib/wild/introspection` | T4 | Thompson (trust boundary) | 23 / 1085 / 30 | 7 |
| L10 | `lib/wild/admin_tools` | T4 | security-auditor | 39 / 2806 / 39 | 16 |
| X1 | engine, config, error tree, README, docs | root | DHH (public surface) | 6 substrate files | 6 |
| X2 | Packwerk, CI, release, test posture | cross | Beck | CI + spec tree | 7 |

**Evidence gate (scripted).** Every finding had to carry a stable id `f-<lane>-<n>`, a severity P0 to P3, a repo-relative file path, a single line or `N-M` range, a claim of 300 characters or fewer, and a repro starting with one of the allowed read-only prefixes. Failures were downgraded to P3 with a stated reason, never deleted. Same-file overlaps across lanes were deduplicated.

**Refuter lenses (three, majority rule).** Every gated P0/P1 went to three verifiers with distinct questions: (1) does the code do what is claimed (read the cited lines, check Ruby semantics and guards elsewhere), (2) is it reachable from a real entry point (generator, MCP handler, rake task, engine hook, public module method), and (3) does the repro literally run and print what the claim says. Each lens returned refuted yes/no plus a severity recommendation; the final severity is the majority position. Ties go to a hand-check list.

**Spot-verifier.** One pass over all P2/P3 findings, confirming or promoting. It confirmed all 39 and promoted none.

**Bead auditors.** Three chunks covering all 36 beads, each assigned `keep`, `re-scope`, `close-now`, `duplicate`, or `needs-decision` with file, commit, or PR evidence. The merge asserted every id appears exactly once and `unaudited = 0`.

## 2. Findings funnel

| Stage | Count | Note |
| --- | --- | --- |
| Raw findings from 12 lanes | 89 | |
| Downgraded to P3 by the scripted gate | 32 | 1 original P0, 8 original P1, 17 P2, 6 P3. Reasons: multi-range line specs (19), claim over 300 chars (14), overlap dedupe (4), non-repo-relative path or disallowed repro (3); some carry two reasons |
| Gated (passed the format bar) | 57 | |
| P0/P1 sent to the three refuter lenses | 18 | 5 lane-P0, 13 lane-P1 |
| Gate-downgraded P0/P1 hand-checked afterwards (2 lenses) | 9 | all 9 confirmed: 5 at P1, 4 at P2 (section 2.5) |
| Confirmed by majority | 18 | final severities: 1 P0, 8 P1, 9 P2 |
| Refuted by majority | 0 | |
| Unverified (tie or missing votes) | 0 | see 2.3 for the hand-check list anyway |
| P2/P3 retained as advisory backlog | 39 | all 39 confirmed by the spot-verifier, 0 promoted |

Every one of the 18 confirmed findings was reproduced by at least one lens running the cited command against the checkout. Ten of the 18 had their severity lowered by the majority; in nine of those ten the lowering came from the reachability lens (the gem is v0.0.1, unreleased, with stub bins and an empty engine hook, so almost nothing is reachable from a packaged entry point today).

### 2.1 Confirmed findings (18)

Severity column reads lane severity then final severity. Votes column reads the three lenses in order: code-does-what-is-claimed / reachable-from-entry-point / repro-literally-runs, each as the lens's severity recommendation, with `R` marking a lens that voted to refute.

| ID | Sev (lane, final) | File:lines | Claim | Votes |
| --- | --- | --- | --- | --- |
| f-l03-1 | P0, **P0** | `lib/wild/telemetry/pipeline/privacy/redactor.rb:24-35` | `Redactor#redact_turn` redacts `turn.content` only; `turn.metadata` (raw `tool_input`/`tool_output` copied verbatim by `ClaudeCodeAdapter`) passes through unredacted into `JsonExporter` output. Verified end to end through the public `Pipeline.process`: content scrubbed, metadata still carrying an AWS key and an email. A spec pins the pass-through. | P0 / P1 / P0 |
| f-l09-1 | P1, **P1** | `lib/wild/introspection/identity/capability_gate.rb:38-43` | `permitted?` returns `request_context.authenticated?` for every action and resource; any valid API key gets all three tools on every allowlisted model. The in-gem T3 `Wild::CapabilityGate` is never consulted from T4. A spec pins the blanket permission. README advertises `capabilities_path`, which nothing reads. | P1 / P1 / P1 |
| f-l09-3 | P1, **P1** | `lib/wild/introspection/audit/audit_logger.rb:9-14` | `AuditLogger` silently no-ops (no write, no warning, no raise) when `audit_log_path` is unset, and that path is not in the required-config set; introspection runs fully functional with zero audit trail by default while `introspection.rb:5` claims every call is audited. Spec pins the silence. | P1 / P2 / P1 |
| f-l10-1 | P0, **P1** | `lib/wild/admin_tools/guard/nonce_manager.rb:41-57` | Single-use confirmation nonce is check-then-act across three separate mutex acquisitions; `NonceStore#consume!` has no compare-and-set and returns true for an already-consumed entry. Eight parallel confirms of one nonce double-consume 6 to 13 percent of the time, executing a `mutate_destructive` action twice. No concurrency spec exists. | P0 / P1 / P1 |
| f-l10-2 | P1, **P1** | `lib/wild/admin_tools.rb:29-31` | The three concrete adapters (`RailsCacheAdapter`, `SidekiqAdapter`, `FlipperAdapter`, 291 LOC, the whole "works with Rails.cache/Sidekiq/Flipper" story) are never required anywhere; referencing them raises `NameError`; unloaded, so invisible to coverage; zero specs. | P1 / P2 / P1 |
| f-l10-3 | P1, **P1** | `lib/wild/configuration.rb:69-85` | `Wild.config.admin_tools` is read by nothing in `lib/`; the `:default` sentinels never resolve because `Engine#after_initialize` is an empty comment; `AdminTools::Configuration#validate!` has zero callers. The README initializer has no effect and every admin action dies on a nil adapter. Already tracked by open P0 bead `wild-rvv.3.1` and `wild-uku`. | P1 / P2 / P1 |
| f-l01-1 | P1, **P1** | `lib/wild/hooks/audit/logger.rb:16-40` | `Audit::Logger#record` writes context values into the trail via raw `v.inspect`, never calling the purpose-built `Sanitizer` in the same directory. Runner calls it on every handler execution with the caller's raw context. Repro printed `password="hunter2", api_key="sk_live_abc"` in `context_summary`. | P1 / P2 R / P1 |
| f-l02-1 | P1, **P1** | `lib/wild/telemetry/collector/store/retention_manager.rb:19-73` | `RetentionManager` reads and `File.write`s the `JsonLinesStore` file directly, never touching the store's private `@mutex`; a concurrent append during a purge is lost. Concurrent repro (2000 appends racing 300 purges) lost 425 events. | P1 / P2 R / P1 |
| f-l03-2 | P0, **P1** | `lib/wild/telemetry/pipeline/privacy/content_filter.rb:10` | `API_KEY_PATTERN` requires the key name to be followed by optional whitespace then `:` or `=`, so the JSON-quoted `"api_key":"..."` shape that `ClaudeCodeAdapter` itself emits via `JSON.generate` never matches; the secret survives in both content and metadata. The spec only tests the bare `api_key=` shape. | P0 / P2 R / P1 |
| f-l01-2 | P1, **P2** | `lib/wild/hooks/execution/runner.rb:31-39` | `Runner#execute` calls `audit_logger.record` and `health_monitor.record` with no rescue, unlike the deliberate `ErrorIsolator`/`TimeoutGuard` wrapping of the handler itself; a raising observability sink aborts the hook invocation after the handler already ran safely. Note: the fix must not be a bare swallow (that is the F2 anti-pattern); record a meta-failure. | P2 / P2 / P2 |
| f-l02-3 | P1, **P2** | `lib/wild/telemetry/collector/collector/event_receiver.rb:14-24` | `EventReceiver#receive` rescues bare `StandardError` around `@store.append` and returns nil, so `ENOSPC`/`EACCES`/`EIO` are indistinguishable from a schema rejection; `StorageError` is defined and never raised. The silence is spec-pinned as "fire-and-forget", so the residual is the missing counter/log, not the rescue. | P2 / P2 R / P2 |
| f-l07-1 | P1, **P2** | `lib/wild/skillops/registry/store.rb:6-8` | Class comment still says "provides atomic read/write access" while `package.yml:4` one directory up says "NO atomicity, NO durability claims"; `Store` has no mutex, monitor, or CAS. The one file the F5 downgrade was about was never edited. `tests/RTM.md` REQ-006 still reads Uncovered. | P3 / P2 / P2 |
| f-l07-3 | P1, **P2** | `lib/wild/configuration.rb:328-341` | `Wild.config.skillops.enabled` (default false) is read by zero executable lines; `Wild::Skillops.build` returns an identically wired facade either way. Sibling knobs in the same struct are consumed, which isolates `enabled` as inert. Same pattern for `telemetry.collector.enabled`. | P1 / P3 / P2 |
| f-l08-1 | P0, **P2** | `lib/wild/capability_gate/evaluator.rb:178-196` | A caller-supplied non-Hash `context` makes `Hash(context)` raise inside `emit_audit`; the rescue swallows it and the evaluation returns ALLOW with no audit line. Repro: two evaluations, one audit line, both allowed. With the default nil `audit_logger` the drop is fully silent. Only two lens votes were recorded. | n/a / P2 / P1 |
| f-l09-2 | P1, **P2** | `lib/wild/introspection.rb:58-67` | The README's documented `Wild.configure { c.introspection.access_policy_path = ... }` sets a value nothing reads; the runtime policy loader is a separate, never-synced singleton, so introspection denies every call with `model_not_allowed` after following the docs exactly. Fail-closed, already bead `wild-u16`; the actionable delta is the README caveat. | P1 / P2 / P2 |
| f-x1-1 | P0, **P2** | `lib/wild/engine.rb:28-35` | `before_configuration` and `after_initialize` are comment-only; central `Wild.config` never reaches introspection's or admin_tools' own `Configuration` objects and the `:default` adapter sentinels are never resolved. No `spec/dummy/`, so the hooks have never executed anywhere. Restates beads `wild-rvv.3.1`, `wild-u16`, `wild-uku`; value is confirming the trio closes as one PR. The repro as written short-circuits on `&&` after a zero-match `rg`. | P2 / P3 R / P1 |
| f-x2-1 | P1, **P2** | `.github/workflows/release.yml:57-71` | The "Verify readiness" step runs `packwerk check` (exit 1, no Rails app) and `brakeman` (exit 4) without `continue-on-error`, so any `workflow_dispatch` release run fails before tagging. `ci.yml` already wraps both; `release.yml` never got the same treatment. The workflow has never been fired. | P1 / P2 / P2 |
| f-x2-2 | P1, **P2** | `CONTRIBUTING.md:241-247` | Tells contributors to treat local `bundle exec packwerk check` output as binding; the command crashes with `RuntimeError: A Rails application could not be found` before inspecting any file. The same false claim also appears at CONTRIBUTING.md:36 and :104, README.md:110, CLAUDE.md:48, AGENTS.md:37, and `tests/TESTING.md:42`. | P1 / P2 / P2 |

### 2.2 What the votes say about severity

The majority lowered severity on 10 of 18. Reading the refuter reasons together, the pattern is consistent and worth stating once rather than per finding: the code claims held in every case; what did not hold was the assumption that a consumer can reach the path today. Both MCP bins `exit 1` and are excluded from `spec.executables`, `rails g wild:install` prints a pending notice, `Wild::Engine`'s hooks are empty, there is no `spec/dummy/`, the gem has no tags and is not on RubyGems. The only real entry points are in-process public module methods (`ServerFactory.create`, `Pipeline.process`, `Wild::Skillops.build`, `Gate#evaluate`), which is why the findings that touch those (f-l03-1, f-l09-1, f-l09-3, f-l10-1) kept P0/P1 and the ones that need boot wiring or a shipped transport dropped to P2.

### 2.3 Unverified P0/P1 for hand-check

The formal count is zero (no ties, no finding rejected by majority). Six confirmed findings still deserve a human read before a fix is scheduled, because the verifiers were not unanimous or not complete:

| ID | Why hand-check |
| --- | --- |
| f-l01-1 | 2-1 split. Reachability lens refuted on "no in-gem caller constructs `Runner` with a logger"; the other two lenses reproduced the leak through `Runner#execute`, which is public T1 API. Decide whether "public but unwired" counts as P1 in a pre-release gem. |
| f-l02-1 | 2-1 split, same shape: `RetentionManager` is never instantiated in `lib/`. Fix shape also depends on the `wild-rvv.5.3` decision (section 7). |
| f-l02-3 | 2-1 split. The rescue is spec-locked as intended behavior; the residual is observability. Confirm the fix is a counter/log, not a change to the fire-and-forget contract. |
| f-l03-2 | 2-1 split. All three agree the regex misses the JSON-quoted shape; disagreement is only on severity. Decide whether it folds into the f-l03-1 P0 PR (section 7). |
| f-l08-1 | Only two lens votes recorded (code-does-what-is-claimed lens missing). Both recorded lenses reproduced it. Run the third lens or accept P2 by hand. |
| f-x1-1 | 2-1 split and the repro command is malformed (`&&` chain short-circuits). Substance is already carried by three open beads; confirm it is folded, not filed again. |

### 2.4 Refuted P0/P1

None. Every P0/P1 that passed the format gate was reproduced by at least one lens. Compare the IEP wave of 2026-06-11, where 3 of 12 were refuted outright. Zero refutations is a good sign for lane discipline (the `facts.json` pre-seeding kept lanes off the known failures) but it also means the refuter layer never got to prove it can kill a bad claim in this repo; the split votes in 2.3 are the closest thing to that evidence.

### 2.5 Gate downgrades that never reached the refuters (32, nine of them originally P0/P1)

The scripted gate downgraded 32 findings on format alone. Nine of those were lane-rated P0 or P1 and, because they arrived as P3, were never sent to the refuter lenses. They are substantive and should be hand-checked before the fix wave treats them as backlog:

| ID | Orig sev | File | Gate reason | One-line claim |
| --- | --- | --- | --- | --- |
| f-l08-2 | P0 | `lib/wild/capability_gate/audit/schema_validator.rb` | multi-range lines; claim over 300 chars | Default config turns the emit-time validator on (environment defaults to `:development`) while `json_schemer` is dev-only; the `LoadError` is swallowed by `emit_audit` and `audit_logger` is nil, so every decision returns ALLOW with zero audit and zero log. Live run reproduced. |
| f-l08-3 | P1 | `lib/wild/capability_gate/gate.rb` | multi-range lines | `Gate#evaluate`'s blanket rescue swallows the `AuditSchemaError` that `Evaluator` re-raises on purpose, turning the "surface loudly" signal into an audit-blind denial; the gate.rb comment and `gate_spec.rb:150-152` claim the rescue is unreachable. |
| f-l08-4 | P1 | `lib/wild/capability_gate/evaluator.rb:198-217` | claim over 300 chars | `Wild.config.audit_logger` defaults to nil, so any single writer failure is terminally silent while ALLOW is returned; CHANGELOG says only a simultaneous writer-and-logger outage is terminal. |
| f-l10-4 | P1 | `lib/wild/admin_tools/audit/audited_pipeline.rb:26-28` | claim over 300 chars | `AuditedPipeline` delegates `two_phase`; `TwoPhaseFlow` exposes `nonce_manager` and `confirm_and_execute`, so any holder of the pipeline can mint a nonce and run a destructive action with no allowlist, rate limit, blast radius, gate, or audit. Repro: `success [discard_job!] audit_records=0`. |
| f-l10-5 | P1 | `lib/wild/admin_tools/guard/two_phase_flow.rb:34-43` | claim over 300 chars | Denial `Result` carries `internal_reason` and `ResponseFormatter` splats the whole metadata hash to the MCP client, so the client learns not_found vs expired vs already_used vs mismatch, contradicting Security Decision 8's opaque-failure contract. |
| f-l10-6 | P1 | `lib/wild/admin_tools/guard/policy_config.rb` | multi-range lines; claim over 300 chars | `PolicyConfig` requires and validates a `defaults` section but never merges it into action hashes; an action omitting `rate_limit` crashes the limiter with `NoMethodError`, one omitting `blast_radius_cap` crashes the enforcer. |
| f-x1-2 | P1 | `lib/wild/error.rb` | multi-range lines; repro not read-only prefix | Eight documented `Wild::Error` subclasses (`DeniedError`, `PolicyError`, `EvaluationError`, `ForbiddenError`, `ModelNotAllowedError`, `AuthenticationError`, `AnalysisError`, `StorageError`) are never raised in `lib/`; the architecture doc presents them as rescue-able. |
| f-l02-2 | P1 | `lib/wild/telemetry/collector/store/retention_manager.rb` | multi-range lines | Purge rewrites use in-place `File.write` (truncate then write) with no temp-file rename and no fsync; a crash mid-write can blank the whole event log. |
| f-l03-3 | P1 | `lib/wild/telemetry/pipeline/package.yml:1-8` | claim over 300 chars | The three telemetry `package.yml` files assert a live Collector to Pipeline to Analysis data flow that no production code implements; each namespace is standalone today. |

**Hand-check result (2026-08-25, workflow `wf_750b37ea-117`, two lenses each: code-does-what-is-claimed via `ruby-pro`, literal repro via `general-purpose`; every repro was rewritten into a runnable form and run against a tree byte-identical to `339453f` under `lib/`).** All nine were confirmed by both lenses; none refuted. Final severities: **P1** for f-l08-2 (default config yields ALLOW with zero audit and zero log when `json_schemer` is absent), f-l08-3 (Gate rescue swallows the deliberately re-raised `AuditSchemaError`), f-l08-4 (nil default `audit_logger` makes a single writer failure terminally silent), f-l10-5 (denial `internal_reason` leaks to the MCP client), f-l10-6 (policy `defaults` never merged; missing per-action keys crash the limiter/enforcer); **P2** for f-l10-4 (the `two_phase` reader bypasses the guard chain; reachable only by an in-process holder of the pipeline), f-x1-2 (eight documented error classes never raised), f-l02-2 (in-place purge rewrite is not crash-safe; lenses split P1/P2), f-l03-3 (the three telemetry `package.yml` files assert a data flow no code implements; lenses split P1/P2). This lifts the confirmed P0/P1 total to **14** (1 P0, 13 P1) and moves f-l08-2/3/4 into cluster 6 and f-l10-5/6 into cluster 9 as scheduled work rather than backlog.

The remaining 23 downgrades (17 lane-P2, 6 lane-P3) are listed in the companion JSON under `downgraded` with their reasons. Notable among them: f-l08-9 (`file_exists` prerequisite satisfied by any inode, resolved against `Dir.pwd`), f-l08-10 (nil caller becomes subject `""` and is allowed by a wildcard grant), f-l08-11 (the gate's three boot-time loader errors subclass bare `StandardError`, so `rescue Wild::Error` misses a malformed policy), f-l10-9 (every `NonceStore` spawns an unstoppable sweep thread; 50 stores = 50 threads), f-l10-8 (rate-limiter window map grows without bound).

### 2.6 P2/P3 advisory backlog (39, all spot-confirmed)

Severity column is the spot-verifier's recommendation where it differed from the lane.

| ID | Sev | File | One-line |
| --- | --- | --- | --- |
| f-l01-3 | P2 | `lib/wild/hooks/mcp_server/tool_handler.rb:1-40` | `ToolHandler.wrap` has zero consumers; both T4 namespaces keep their own near-duplicate rescue-and-format handlers. |
| f-l01-4 | P2 | `lib/wild/hooks/execution/timeout_guard.rb:16-25` | Stdlib `Timeout.timeout` around arbitrary handler blocks with no `Thread.handle_interrupt`; can corrupt a non-reentrant resource mid-operation once real handlers are wired. |
| f-l01-5 | P3 | `lib/wild/hooks/audit/sanitizer.rb:1-90` | `Sanitizer` is unreferenced outside its own file and spec (pairs with f-l01-1). |
| f-l02-5 | P2 | `lib/wild/telemetry/collector/store/storage_monitor.rb:1-57` | `StorageMonitor`, `Export::Exporter`, `RecordBuilder`, `Aggregation::Engine`, `PatternDetector` are built and spec'd but never instantiated in `lib/`. |
| f-l03-5 | P2 | `lib/wild/telemetry/pipeline/export/json_exporter.rb:1-56` | Both pipeline exporters are required but never called from `Pipeline.process`. |
| f-l03-6 | P3 | `lib/wild/telemetry/pipeline/privacy/content_filter.rb:28-42` | `ContentFilter#sensitive?` and `#patterns_matching` have no production callers; `Redactor` uses the raw constants. |
| f-l04-1 | P3 | `lib/wild/telemetry/analysis/models/event_record.rb:7-38` | `EventRecord` flattens identity, unparsed time string, and value into one mutable object (F8). |
| f-l04-3 | P3 | `lib/wild/configuration.rb:174-192` | `telemetry.analysis.gap_threshold` is a documented placeholder read by nothing; `gap_report.rb:48` hardcodes 0.7. |
| f-l04-5 | P3 | `lib/wild/telemetry/analysis/models/telemetry_record.rb:10-17` | `@raw = data` stored by reference, no dup or freeze; only `#to_h` dups on read. |
| f-l05-1 | P2 | `lib/wild/analyzers/permission/analyzers/wildcard_matcher.rb:14-19` | Fresh `Regexp.new` per `matches?` call; measured ~20x slower than a cached regexp at the 500x200 shape-test scale. |
| f-l05-3 | P3 | `spec/wild/schemas/wildcard_corpus_spec.rb:53-58` | Spec checks `non_matches` is an Array, never non-empty for non-universal patterns (bead `wild-96t`). |
| f-l05-4 | P3 | `lib/wild/capability_gate/package.yml:12-13` | Claims capability_gate "shares" `wildcard_corpus.yml`; no runtime reference exists; the gate deliberately does not wildcard-match. |
| f-l05-6 | P3 | `lib/wild/analyzers/permission/analyzers/coverage_analyzer.rb:1-45` | Bead `wild-rvv.7.2`'s premise (a test_flakes `coverage_analyzer.rb`) does not exist. |
| f-l06-1 | P2 | `spec/wild/analyzers/test_flakes/adversarial/edge_cases_spec.rb:23-159` | 8 of 13 examples assert only `not_to raise_error`; no output correctness for special chars, 1000 results, path traversal, unicode. |
| f-l06-2 | P3 | `spec/wild/analyzers/test_flakes/export/json_exporter_spec.rb:40-42` | `avg_flake_rate` asserted `be_a(Numeric)`, never the computed value. |
| f-l06-3 | P3 | `spec/wild/analyzers/test_flakes/models/test_result_spec.rb:16-21` | Tautological constructor round-trip test. |
| f-l06-4 | P2 | `lib/wild/analyzers/test_flakes/package.yml:10-11` | Declared Packwerk edges on `../../hooks` and `../../telemetry/analysis` with zero code references to either. |
| f-l06-6 | P3 | `000-docs/002-PP-PRD-product-requirements.md:83` | FR-8 claims a Beck golden-corpus test that does not exist anywhere in `spec/`. |
| f-l07-2 | P2 | `lib/wild/skillops/registry/store.rb:13-21` | `Store#add` is check-then-set with no synchronization; capacity limit not enforced under concurrent callers. |
| f-l07-4 | P3 | `spec/wild/skillops/adversarial/edge_cases_spec.rb:114-124` | "Concurrent-style sequential updates" is a plain `10.times` loop; no `Thread` anywhere under `spec/wild/skillops/`. |
| f-l07-6 | P2 | `lib/wild/skillops.rb:1-107` | Whole namespace (19 files, 1069 LOC) has zero executable consumers outside its own files; loaded unconditionally from `lib/wild.rb`. |
| f-l08-6 | P2 | `lib/wild/configuration.rb:87-96` | `capability_gate.capabilities_path` is README-documented and read by nothing; `Gate` takes `config_path:` directly. |
| f-l08-8 | P2 | `lib/wild/capability_gate/session.rb:18-61` | `Session` and `Session::Store` (105 LOC) referenced by nothing; `Gate` takes a `session_id` String. Two latent defects if wired: cache key ignores context, `expired?` never consulted by `Session#evaluate`. |
| f-l08-14 | P3 | `lib/wild/capability_gate/audit/json_lines_writer.rb:26-30` | Audit file created with umask-default mode (0664 observed), never fsync'd, no size cap, unbounded caller `extra` despite a "<2 KiB" schema comment. |
| f-l09-4 | P2 | `lib/wild/introspection/adapter/write_prevention.rb:6-48` | `WritePrevention` documented as read-only enforcement, never called from any adapter, guard, or tool. |
| f-l09-5 | P2 | `lib/wild/introspection/adapter/connection_manager.rb:6-44` | Replica routing never invoked; `read_replica_used` is permanently false. |
| f-l09-6 | P3 | `lib/wild/introspection/adapter/model_reflector.rb:6-22` | `ModelReflector.reflect` unreachable from any tool or guard. |
| f-l09-7 | P3 | `lib/wild/introspection/identity/capability_gate.rb:18` | Cites `009-AT-ADEC-capability-gate-interface.md`, which does not exist. |
| f-l10-7 | P2 | `lib/wild/admin_tools/guard/pipeline.rb:91-94` | Only 3 of 19 actions emit `estimated_affected`; the other 16 (including `enable_flag_percentage`) score as 1 and pass any cap. Count-vs-execute mismatch on `retry_jobs_by_filter`. |
| f-l10-10 | P2 | `lib/wild/admin_tools/executor/state_capture.rb:53-77` | Bulk-action before/after snapshots are fabricated: `invalidate_cache_pattern` records `cleared: true` from a literal-key miss; `*_jobs_by_filter` captures nothing. |
| f-l10-12 | P2 | `lib/wild/admin_tools/guard/pipeline.rb:38-48` | Routing trusts the policy's `operation`; nothing cross-checks the executor's `ACTION_MAP`, so a policy mislabeling `delete_flag` as `read` executes it unconfirmed. |
| f-l10-13 | P2 | `lib/wild/admin_tools/server/tool_handler.rb:16-18` | Every `StandardError` message is returned verbatim to the MCP client (adapter internals, nil-receiver text). |
| f-l10-14 | P3 | `lib/wild/admin_tools/executor/adapters/rails_cache_adapter.rb:22-32` | `list_keys(prefix:)` required keyword vs the abstract `**_options` and the tool schema's optional `prefix`. |
| f-l10-16 | P3 | `lib/wild/admin_tools/guard/pipeline.rb:71-80` | Every mutation runs `executor.preview` twice per phase. |
| f-x1-5 | P3 | `README.md:20` | Says `prompts/` "does not exist"; two `.keep` placeholder dirs exist. |
| f-x2-4 | P2 | `tests/TESTING.md:68` | Asserts a stopwatch test in `spec/stopwatch/` already backs the L6 waiver; directory does not exist; PRD says Role 8/11. |
| f-x2-5 | P3 | `package.yml:1-14` | Root package claims to own the 5 engine files that `packwerk.yml` excludes from the scan. |
| f-x2-6 | P3 | `Rakefile:28-31` | `rake test:engine` passes green with 0 examples (`spec/engine/` is `.keep` only). |
| f-x2-7 | P3 | `spec/wild/capability_gate_spec.rb:1-14` | Top-level spec for the T3 security namespace holds two vanity examples (VERSION regex, `be_a(Module)`); same in `permission_spec.rb`. |

## 3. Namespace health

Grades are the lane's own synthesis grade, unchanged by the verifiers. Summaries are rewritten here in one line each; the full lane summaries, dead-code lists, and doc-drift lists are in the companion JSON.

| Lane | Grade | One-line summary |
| --- | --- | --- |
| L01 hooks | B | Core execution pipeline is well composed and honestly tested, and the trail buffer is genuinely thread-safe; two real gaps (audit path not error-isolated, Logger never calls its own Sanitizer) and the whole namespace has zero live callers, so package.yml describes a target architecture, not current fact. |
| L02 telemetry/collector | C | Honest about being a process-local buffer, but purge and append share no lock, purge rewrites are not crash-safe, disk failures are indistinguishable from validation rejects, and five fully built classes are never instantiated. |
| L03 telemetry/pipeline | D | The flagship privacy promise fails on its own adapter's output (metadata never redacted, JSON-quoted keys never matched); the Collector to Pipeline to Analysis boundary exists only in package.yml comments; exporters are dead code; malformed-input handling is inconsistent. |
| L04 telemetry/analysis | C | Tier boundary is clean (never imports Collector), but F8 is unaddressed as coded (Gap has no id or sequence, EventRecord is flat and mutable), EventRecord is dead weight, gap_threshold is a documented dead knob, and bead 7.2's premise is wrong for this lane. |
| L05 analyzers/permission | B | Shipped its hard problem (tri-color DFS cycle detection) correctly with a negative-existence spec for the old bug; F4 is vacuously satisfied; leftovers are cheap (wildcard detection copy-pasted at six sites, uncached regexp ~20x slow, two overclaiming doc comments). |
| L06 analyzers/test_flakes | C | Parser layer is defensively coded and all 253 specs pass, but every fixture is synthetic, the golden corpus package.yml and the PRD both claim does not exist, the adversarial spec asserts only no-raise, exporters are unconsumed, and declared Packwerk edges are fictional. |
| L07 skillops | C | Well tested but functionally inert: the enabled flag gates nothing, Store still carries the exact "atomic" claim F5 was opened to remove, the only concurrency-labeled spec is sequential, and zero code outside its own files touches it. |
| L08 capability_gate | C | The most carefully argued namespace in the gem, with real adversarial specs, but F2 is closed only for the machinery-raises scenario: a non-Hash context, the default dev-only validator, and the Gate's blanket rescue each yield an audit-blind ALLOW or a dark denial; Session/Store unwired; several config knobs inert; no in-gem consumer despite package.yml claims. |
| L09 introspection | C | Data-safety invariants hold (field-name injection blocked twice, YAML safe, constant-time key compare), but the README config example silently configures nothing, the "every call audited" claim is false by default, the identity gate grants everything to any valid key, and WritePrevention, ConnectionManager, ModelReflector are dead. |
| L10 admin_tools | C | Best-articulated safety architecture in the gem with genuinely adversarial safety specs, but the nonce primitive double-consumes under contention, the concrete adapters cannot be loaded, the central config is read by nobody, and several controls are weaker than their names (two_phase bypass, leaked internal reasons, blast radius defaulting to 1, defaults never applied). |
| X1 engine / public surface | C | README and CHANGELOG are unusually honest post-#53, but Wild::Configuration is a facade for two of four T3/T4 namespaces, the engine hooks are empty comments, eight documented error classes are never raised, and the PRD's HTTP-mounted stopwatch script has no transport in the tech spec or the code. |
| X2 boundaries / CI / tests | C | RSpec, RuboCop, CodeQL are real and green (3076 examples, 98.2 percent coverage), the ADR-0003 DAG holds in actual code references, but boundary enforcement and the release path are theater (packwerk and brakeman crash, release.yml cannot pass), spec/engine is empty, TESTING.md is three months stale, and two top-level specs are pure vanity. |

## 4. Bead outcomes

All 36 open and in-progress beads dispositioned. `unaudited: 0`. No duplicates found. No unknown ids.

> **Applied 2026-08-25 (E2.4, by hand, one op per command, JSONL verified after each):** 3 of the 4 close-now beads closed via `bd-sync close` with the evidence line (`wild-rvv.11`, `wild-rvv.12`, `wild-rvv.1.5`); `wild-rvv.8.2` was **held open as needs-decision** because of the F10 conflict in section 5 / decision 7.4. The 5 re-scope beads carry a `bd-sync note` (and `wild-rvv.7.2` a corrected description). The 2 needs-decision beads plus `wild-rvv.5.3` carry the question as a note. Net: 33 non-closed consolidation beads remain (25 keep, 5 re-scoped, 3 needs-decision), 6 still in_progress.

| Disposition | Count | Outcome |
| --- | --- | --- |
| keep | 25 | Still true against the code; several now carry confirmed finding ids as fresh evidence. |
| re-scope | 5 | The move landed but the bead text points at the old scope; description notes to apply. |
| close-now | 4 | Verified done with file or commit evidence; close one at a time via `bd-sync close` with the evidence line. |
| duplicate | 0 | |
| needs-decision | 2 | Design decisions Jeremy owns; note only, no state change. |

The six in-progress move epics (`wild-rvv.2`, `.5`, `.6`, `.7`, `.8`, `.6.2`) stay in progress per the plan; three of them get a re-scope note narrowing remaining work to their open children.

### 4.1 Needs decision (2)

| Bead | Question |
| --- | --- |
| `wild-0c3` "Decide the fail-closed posture for ALLOW results when both the audit writer and logger are dark" | When both the audit writer and the configured logger fail for an ALLOW result, should the gate (a) degrade the result to DENY (fail-closed), or (b) return ALLOW with an `audit_degraded` flag the caller must explicitly honor? This decision also governs the concrete trigger in f-l08-1 (non-Hash context) and the gate-downgraded f-l08-4 (nil default logger). |
| `wild-28y` "Decide-or-cut the inert on_evaluation_error knob + unraised CapabilityGate::EvaluationError class" | Wire `on_evaluation_error`'s `:hard_fail` default to actually raise `Wild::CapabilityGate::EvaluationError` after emitting the audit event (option a), or delete both the knob and the unraised class and document the gate as unconditionally fail-closed-deny (option b)? The configuration.rb comment still reads CURRENTLY INERT. |

One `keep` bead also recorded a decision text and belongs in the same conversation: `wild-rvv.5.3` (MIN-Kleppmann) asks Jeremy to pick a horn now that f-l02-1 shows the collector is unsafe under concurrent purge: (a) implement locking plus fsync or atomic-rename discipline and keep the durable-log framing, or (b) drop the append-only claims and document the collector as a process-local buffer only.

### 4.2 Close now (4)

| Bead | Evidence |
| --- | --- |
| `wild-rvv.11` "Set up CodeQL with security-extended on ruby + actions matrix" | Fully shipped on main: `.github/workflows/codeql.yml` (ruby + actions matrix, security-extended), `.github/codeql/codeql-config.yml`, `000-docs/007-AT-STND-codeql-strategy.md`. Landed in commit `6d2a9d4` (#6); later touched only by dependency bumps. Weekly scheduled runs green. |
| `wild-rvv.12` "Install audit-harness vendored + plain-shell git hooks + harness-hash init" | `.audit-harness/` vendored at v1.1.5, `scripts/git-hooks/{pre-commit,commit-msg,pre-push}`, `scripts/install-hooks`, `.harness-hash` present. Landed in `f719758` (#10), kept current via `f18b86c` (#43). |
| `wild-rvv.1.5` "Static-grep survey gap: stringly-typed const lookups not covered by PR-E" | The only dynamic const lookup in `lib/` is `lib/wild/introspection/configuration.rb:107-114` `safe_resolve_constant`, guarded by `CONSTANT_NAME_PATTERN` before `Object.const_get` with `NameError` rescued to nil. Resolved at the Role 5 introspection move (PR #30, `a59d72c`). No unsafe instance exists. |
| `wild-rvv.8.2` "F10: Cut back BDUF docs that predate any consumer" | No per-namespace doc dumps exist: `lib/wild/skillops/` and `lib/wild/analyzers/test_flakes/` hold only `package.yml` and `.keep`; `000-docs/` holds the unified canonical set (index, nine numbered docs, `adr/`). **Caution:** lane X1 read F10 as still open because the three root BDUF docs (002 PRD, 003 ARCH, 005 SPEC) are unchanged since 2026-05-28 and drifting. See section 5 row F10 and section 7. |

### 4.3 Re-scope (5)

| Bead | Note to apply |
| --- | --- |
| `wild-rvv.2` "Move wild-rails-safe-introspection-mcp into Wild::Introspection" | Move landed (PR #30). Remaining scope is its two children only: `wild-u16` (bridge `Wild.config.introspection.access_policy_path` into the runtime singleton at engine boot; root cause of f-l09-2) and `wild-rvv.2.1` (real `prompts/` content and `bin/eval` stub; today only `.keep` files). Stays in progress. |
| `wild-rvv.8` "Move wild-skillops-registry into Wild::Skillops as internal namespace with downgraded claims (F5)" | Move landed (19 files, 1069 LOC, specs). Remaining scope after `wild-rvv.8.2` closes: `wild-rvv.8.1` (P0, downgrade the claims; f-l07-1, f-l07-2, f-l07-3, f-l07-6 confirm they are still false) and `wild-rvv.8.3` (F6 audit of the export pair). Stays in progress. |
| `wild-rvv.6` "Move wild-hook-ops into Wild::Hooks as the shared-concerns landing zone" | Structural move landed (`mcp_server/`, `audit/`, `execution/` extracted). Narrow to the sole open child `wild-rvv.6.2`: wire `Hooks::Audit::Sanitizer` into `Logger#record` (f-l01-1) and either adopt `Hooks::McpServer::ToolHandler.wrap` in the T4 namespaces or delete it (f-l01-3). Stays in progress. |
| `wild-rvv.6.2` "Extract audit-logging pattern to Wild::Hooks::Audit substrate" | Extraction landed but not adopted. Narrow remaining scope to: (1) route `Logger#record` context through `Sanitizer` (f-l01-1), (2) isolate `Runner#execute`'s `audit_logger.record` / `health_monitor.record` calls without a bare swallow (f-l01-2), (3) wire-or-delete `ToolHandler.wrap` (f-l01-3). Overlaps `wild-rvv.4.2`. |
| `wild-rvv.7.2` "Reconcile analyzers/coverage_analyzer.rb duplication (permission + test_flakes)" | Cited paths (`lib/wild_permission_analyzer/...`, `lib/wild_test_flake_forensics/...`) do not exist and test_flakes has no `coverage_analyzer.rb` at all (f-l05-6, facts `bead-7.2-phantom-paths`). The real pair is `lib/wild/analyzers/permission/analyzers/coverage_analyzer.rb` vs `lib/wild/telemetry/analysis/analyzers/coverage_analyzer.rb`, which share a name but operate on disjoint domain models. Retarget to that pair and re-run the (a) shared base / (b) keep with documented divergence / (c) delete-unused decision; consider re-parenting under `wild-rvv.5`. |

### 4.4 Keep (25)

`wild-rvv`, `wild-rvv.9`, `wild-rvv.9.1`, `wild-rvv.10`, `wild-rvv.13`, `wild-rvv.1.4`, `wild-rvv.2.1`, `wild-rvv.3`, `wild-rvv.3.1`, `wild-uku`, `wild-rvv.4`, `wild-rvv.4.2`, `wild-rvv.4.3`, `wild-u16`, `wild-rvv.8.1`, `wild-rvv.7.1`, `wild-rvv.5.3`, `wild-rvv.5.2`, `wild-rvv.5.1`, `wild-rvv.7`, `wild-rvv.5`, `wild-96t`, `wild-rvv.8.3`, `wild-rvv.5.4`, `wild-yms`. Each carries an evidence line and, where applicable, the finding ids that re-confirm it, in the companion JSON. The three open P0s (`wild-rvv.3.1`, `wild-rvv.7.1`, `wild-rvv.8.1`) all keep and all gained confirmed findings as evidence.

## 5. Council-fix ledger delta

STATUS claim is the `build-orchestration/STATUS.md` ledger as carried in `facts.json`. Observed is what the lanes reported per council fix (`closed | partial | open | regressed | not-applicable`). Delta is what the ledger should say after this wave.

| # | Code | STATUS claim | Observed by lanes | Delta |
| --- | --- | --- | --- | --- |
| 1 | F1 (one typed Configuration) | Closed (evidence regressed) | X1 regressed; L09 regressed; L10 regressed | **Reopen as regressed.** Three `class Configuration` in `lib/`; introspection and admin_tools keep their own, never bridged at boot; admin_tools' central slice is write-only dead state (f-l10-3, f-l09-2, f-x1-1). Owned by `wild-rvv.3.1`, `wild-u16`, `wild-uku`. |
| 2 | F2 (audit-blind ALLOW) | Closed (#32, #36, #37, #41, #42) | L08 partial; L01 n/a (substrate not fit as F2 emitter); L09 n/a (T4 has its own audit-blind default); L10 n/a (boundary fails closed correctly) | **Closed narrowly; annotate.** The machinery-raises scenario is closed. Three audit-blind paths remain in T3, two introduced by #41/#42 (f-l08-1 confirmed P2; f-l08-2/3/4 gate-downgraded, unrefuted), and T4 introspection has an un-beaded instance of the same class (f-l09-3, P1). Governed by the `wild-0c3` decision. |
| 3 | F3 (vanity tests) | Open | L05 partial (already judgment tests here); L06 open; L08 open (config-coverage gap, not vanity); L10 partial; X2 open | Matches. Evidence widened: f-l06-1/2/3, f-l07-4, f-x2-7, f-l06-6; two top-level specs are pure vanity; no spec exercises `json_schemer`-absent or `:production` configs. |
| 4 | F4 (grammar drift, schemas as data) | Closed (PR-D + #34) | L05 partial; L08 partial | **Closed vacuously; fix the docs.** CapabilityGate performs no capability-name wildcard matching, so there is nothing to drift. `capability_gate/package.yml:12-13` overclaims a shared corpus (f-l05-4, f-l08-12); `audit_event.yml:135` risk_level vocabulary differs from `Capability::VALID_RISK_LEVELS`. |
| 5 | F5 (skillops claims) | Open | L07 partial | Matches, with a precise residual: `registry/store.rb:7` still says "atomic" (f-l07-1), the enabled flag gates nothing (f-l07-3). `wild-rvv.8.1` must not close on current state. |
| 6 | F6 (half-published API) | Open | L01 open; L03 open; L06 partial; L08 open; L09 open; L10 open | Matches; surface is wider than the bead lists. Six lanes independently found dead or unwired classes (hooks substrate, five collector classes, both pipeline exporters, test_flakes exporters, Session/Store, WritePrevention/ConnectionManager/ModelReflector, three admin adapters, eight error classes). `capability_gate/package.yml:15` claims "Session/Store wired in or deleted (Role 6 decision)"; Role 6 did neither. |
| 7 | F7 (boundary normalization) | Open | L02 open (no ordering primitive); L03 open (zero wiring exists); L04 closed for analysis (never imports Collector) | Matches; escalated. The boundary component that exists (Redactor) leaks secrets: f-l03-1 is the wave's only P0. |
| 8 | F8 (decomplect identity/value/time) | Open | L04 open | Matches. Gap has no id or sequence; EventRecord flat and mutable (f-l04-1, f-l04-5). |
| 9 | F9 (install generator) | Open | X1 open | Matches. Generator is a one-method stub. Out of scope for this wave. |
| 10 | F10 (cut BDUF docs) | Open | X1 open (root BDUF docs unchanged and drifting) | **Conflict.** Bead audit says close `wild-rvv.8.2` (no per-namespace doc dumps exist); lane X1 says the root BDUF set is still in place and drifting (f-x1-3, f-x1-6). Both are factually right about different documents. Needs Jeremy's read of what F10 meant (section 7). |
| 11 | MIN-Kleppmann (fsync or drop framing) | Open | L02 partial | Matches; forced. The architecture doc already writes the compromise, but f-l02-1 (P1) shows even the downgraded framing is not safe under concurrent access, and f-l02-2 shows purges are not crash-safe. Decision `wild-rvv.5.3` now blocks the collector fix cluster. |
| 12 | MIN-Karpathy (prompts/ + bin/eval) | Open | X1 open | Matches. Only two `.keep` files; no `bin/eval`. Out of scope for this wave. |
| 13 | MIN-Armstrong (Wild::Error tree) | Closed (Role 4 PR-C) | L08 partial (regressed for loaders); L10 closed; X1 partial | **Closed for admin_tools, regressed for capability_gate.** The gate's three boot-time loader errors subclass bare `StandardError`, so `rescue Wild::Error` misses a malformed policy while `PolicyError` is never raised (f-l08-11, downgraded); eight documented subclasses are never raised anywhere (f-x1-2, downgraded). Owned by `wild-rvv.13` and `wild-28y`. |

Net: of the four fixes the ledger calls closed, one is regressed (F1), one is closed narrowly with new instances (F2), one is closed vacuously with overclaiming docs (F4), and one is closed in one namespace and regressed in another (MIN-Armstrong). The nine open fixes all match the ledger; two of them (F7, MIN-Kleppmann) are now backed by confirmed P0/P1 findings and are blocking.

## 6. Fix clusters proposed

Grouping rule per the plan: Packwerk package times severity band; a P0 always gets its own PR; cross-namespace seam fixes cluster under the provider (lower tier); order is P0 first, then P1s tier-up (T1 hooks and telemetry, then T2, then T3 capability_gate, then T4 introspection and admin_tools), then P2. Hard constraints from the plan: the hooks audit substrate (`wild-rvv.6.2`) lands before any admin_tools audit fix; the engine boot wiring (`wild-rvv.3.1` + `wild-u16`) lands before any T4 fix that assumes resolved config; a `spec/dummy/` PR (or an honest removal of the two lanes) lands before any packwerk-dependent fix. Branch `fix/<pkg>-<f-id>`, at most ~400 non-spec lines and 10 non-spec files, `/code-review high` on every PR, `/security-review` on T3, T4, and any `*/audit/` PR. Each cluster below is an E3 epic bead once Jeremy approves the shape.

| Order | Cluster (plain-English title) | Package / band | Findings | Beads | Notes and prerequisites |
| --- | --- | --- | --- | --- | --- |
| 1 | Redact turn metadata in the pipeline privacy layer so tool inputs never reach exported telemetry unscrubbed | `telemetry/pipeline`, **P0, own PR** | f-l03-1 | `wild-rvv.5.1`, `wild-rvv.5` | Recursive string redaction over `turn.metadata` (or stop the adapters copying raw `tool_input`/`tool_output`), plus a redactor spec and an integration spec asserting metadata is scrubbed. Ships first. `/security-review` required. |
| 2 | Match JSON-quoted secret keys in the content filter so the adapter's own output shape is redacted | `telemetry/pipeline`, P1 | f-l03-2 (+ f-l03-6 P3 rides along) | `wild-rvv.5.1` | Either broaden the patterns to tolerate a closing quote before the separator or redact at the structured-data level. Decision 7.8 asks whether it folds into cluster 1. |
| 3 | Route hook audit records through the Sanitizer and isolate the observability path in the Runner | `hooks` (T1), P1 | f-l01-1, f-l01-2 (+ f-l01-3, f-l01-5 ride along) | `wild-rvv.6.2`, `wild-rvv.6` | Inject `Sanitizer` into `Logger` (default on), spec that a password key never appears in `context_summary`; wrap `audit_logger&.record` / `health_monitor&.record` so a broken sink records a meta-failure rather than crashing the invocation (no bare swallow: that is the F2 anti-pattern). Hard prerequisite for cluster 9. |
| 4 | Make retention purges hold the store lock and surface real store failures instead of a silent nil | `telemetry/collector` (T1), P1 | f-l02-1, f-l02-3 (+ f-l02-2, f-l02-5 ride along) | `wild-rvv.5.3`, `wild-rvv.5.4` | `JsonLinesStore#compact(&block)` holding `@mutex` for the read-modify-write, temp-file plus `File.rename` instead of in-place `File.write`; a counter or log on swallowed store errors, `StorageError` raised or deleted. Shape depends on decision 7.3 (Kleppmann horn). |
| 5 | Fill the engine after_initialize hook so central config actually reaches introspection and admin_tools | root engine (provider for T4), P1 | f-l10-3, f-x1-1, f-l09-2 | `wild-rvv.3.1`, `wild-u16`, `wild-uku`, `wild-rvv.1.1` | Resolve `:default` sentinels to `Rails.cache` / `ActiveJob::Base` / `Flipper` when defined and assign into `Wild::AdminTools.configuration`, call `validate!` and raise `ConfigurationError` at boot; push `access_policy_path` into `Wild::Introspection::Configuration` and `load!`. Needs a minimal `spec/dummy/` to exercise the hook (see cluster 10). Closes the F1 regression. Hard prerequisite for clusters 7 and 8. |
| 6 | Coerce caller context at the gate boundary so every evaluation emits exactly one audit event | `capability_gate` (T3), P2 with security weight | f-l08-1 (+ hand-checked f-l08-2, f-l08-3, f-l08-4, f-l08-5 if confirmed) | `wild-rvv.4`, `wild-0c3`, `wild-28y` | Never-raising `safe_context` in `SafeCoercion`, Gate-level spec asserting one audit line per evaluate for hostile context; `rescue AuditSchemaError; raise` above the Gate's blanket rescue; probe the audit path at construction; default `audit_logger` to a real fallback. Shape depends on decisions 7.1 and 7.2. `/security-review` required. |
| 7 | Wire the introspection identity gate to Wild::CapabilityGate and stop the audit logger from silently skipping | `introspection` (T4), P1 | f-l09-1, f-l09-3 (+ f-l09-4/5/6/7 ride along under F6) | `wild-rvv.4.2`, `wild-u16` | Build a memoized `Wild::CapabilityGate::Gate` at boot (T4 to T3 is an allowed ADR-0003 edge) and make `permitted?` call `gate.evaluate`; rewrite the pinned "permits all actions in v1" spec to assert per-action differentiation; either add `audit_log_path` to `validate_paths!` or warn loudly once when nil. Prerequisites: cluster 5 (boot wiring) and cluster 6 (gate posture). `/security-review` required. |
| 8 | Make nonce consumption atomic and load the three concrete admin adapters | `admin_tools` (T4), P1 | f-l10-1, f-l10-2 (+ f-l10-14, f-l10-15 ride along) | `wild-rvv.3`, `wild-rvv.3.1`, `wild-rvv.4.2` | `NonceStore#consume_if_unconsumed!` inside the existing mutex, `NonceManager` treating false as `nonce_already_used`, a concurrency spec asserting exactly one of N parallel confirms succeeds; add the three `require`s and a shared-examples adapter interface spec (fixes the `prefix:` arity mismatch). Prerequisite: cluster 5 (otherwise the adapters load but nothing resolves them). `/security-review` required. |
| 9 | Close the admin_tools guard-chain bypasses and stop leaking internals to the client | `admin_tools` (T4), P2 (gate-downgraded P1s pending hand-check) | f-l10-4, f-l10-5, f-l10-6, f-l10-7, f-l10-10, f-l10-12, f-l10-13 | `wild-rvv.4.2`, `wild-rvv.6.2` | Drop the `two_phase` reader and delegation, whitelist `denied_hash` keys, merge policy `defaults` into actions, make `estimated_affected` mandatory for mutating previews, honest bulk snapshots, cross-check policy `operation` against `ACTION_MAP` at registration, opaque client error messages. Prerequisite: cluster 3 (hooks audit substrate) per the plan's hard constraint. Only after 2.5 hand-check confirms the four P1s. |
| 10 | Land a minimal dummy Rails app so packwerk, brakeman, and the release workflow become real | cross-cutting CI, P2 | f-x2-1, f-x2-2 (+ f-x2-5, f-x2-6, f-x2-4 ride along) | `wild-rvv.9` (spec/dummy only, not the generator) | `spec/dummy/` with `Wild::Engine` mounted, `boundary` joins `ci-ok`, `release.yml` inherits the same semantics, CONTRIBUTING and the six other packwerk claims corrected, an engine smoke spec so `rake test:engine` stops passing on zero examples. Honest fallback per the plan: remove the two lanes and say so in STATUS. Decision 7.5. Provider for cluster 5's spec. |
| 11 | Remove the atomicity claim from the skillops store and make the enabled flag mean something or nothing | `skillops` (T2), P2 | f-l07-1, f-l07-3, f-l07-2, f-l07-4, f-l07-6 | `wild-rvv.8.1`, `wild-rvv.8.3` | Delete "and provides atomic read/write access" from `store.rb:7`, document Store as single-threaded or add a Monitor, rename the sequential spec, then either gate the `require` on `enabled` or reframe the flag as advisory (decision 7.10). Closes `wild-rvv.8.1`. |
| 12 | Correct the doc claims the review proved false without touching the locked architecture docs | docs (T2 analyzers, telemetry, capability_gate package.yml, TESTING.md, PRD line) | f-l05-4, f-l05-6, f-l06-4, f-l06-6, f-x1-5, f-x2-4, f-x2-7, f-l09-7, f-l08-6 | `wild-rvv.7.1`, `wild-rvv.7.2`, `wild-96t`, `wild-yms` | Lightweight lane. Package.yml overclaims (F4 sharing, fictional dependency edges, "gates every admin operation"), stale references, vanity spec files deleted or given a real smoke assertion, `wildcard_corpus_spec` non-empty guard, `WildcardMatcher.wildcard?` centralization and a cached regexp. Last PR before the E4.2 truth pass. |

P2/P3 findings not named above (f-l01-4, f-l04-1, f-l04-3, f-l04-5, f-l08-8, f-l08-14, f-l10-16, and the remaining gate-downgrades) stay as advisory backlog attached to their namespace bead and are not scheduled in this wave.

## 7. Decisions needed

1. **`wild-0c3`: fail-closed posture when the audit path is dark for an ALLOW.** Degrade to DENY, or return ALLOW with an explicit `audit_degraded` flag? Governs cluster 6 and the shape of f-l08-1, f-l08-4, f-l09-3. Today's shipped posture is fail-open with no record anywhere, which nobody chose.
2. **`wild-28y`: decide-or-cut `on_evaluation_error` and `EvaluationError`.** Option (a) wire, option (b) delete both and fix `003-AT-ARCH:81,107`. Affects clusters 6 and 12.
3. **`wild-rvv.5.3` (MIN-Kleppmann): pick the horn.** Locking plus fsync/atomic-rename and keep the durable-log framing, or drop the framing and document a process-local buffer. Cluster 4 cannot be shaped until this is answered.
4. **F10 ledger vs bead docket conflict.** Bead audit says close `wild-rvv.8.2` (no per-namespace doc dumps); lane X1 says the three root BDUF docs are the F10 target and are still drifting. Decide which reading F10 meant; if X1's, keep the bead and re-scope it to the root docs.
5. **`spec/dummy/` or remove the lanes.** The plan allows either; cluster 10 and the release path depend on it. A dummy app also gives cluster 5 a place to test the engine hook, which argues for building it.
6. **Hand-check the nine gate-downgraded P0/P1s (section 2.5)** before treating them as P3 backlog. f-l08-2 (default config yields ALLOW with zero audit and zero log) and f-l10-4 (guard-chain bypass with zero audit) are the two that most look like they belong in clusters 6 and 9.
7. **Accept f-l08-1 at P2 on two lens votes, or run the missing third lens.**
8. **Fold f-l03-2 into the P0 PR (cluster 1) or keep it as its own P1 PR.** The plan's "P0 gets its own PR" rule argues for separate; the two fixes touch the same three files and the same spec, which argues for one reviewable diff.
9. **F2 ledger wording.** Keep "Closed" with an annotation, or flip to "Closed (narrow), reopened items under wild-0c3". The evidence supports the second.
10. **What `Wild.config.skillops.enabled` (and `telemetry.collector.enabled`) should mean.** Gate the `require` (real off switch), or delete the flags and say the namespaces are always loaded. Adding raise-if-disabled semantics to `build` would invent an enforcement no ADR decided.
11. **Showcase.** Deferred to Stage 4 (E4.3) per the plan; this record supplies the input. Headline for that decision: the gem's three trust promises (privacy-aware telemetry, gated admin actions, audited introspection) each have one confirmed P0/P1 against them today.

## 8. Process lessons

1. **The format gate was too strict and it silently removed security findings from the verification path.** 32 of 89 findings (36 percent) were downgraded on format alone; nine were lane-rated P0/P1, including the only finding that shows the default configuration produces an audit-blind ALLOW with no log at all (f-l08-2). Multi-range line specs (`33-39,66-76`) and claims over 300 characters are the two triggers. Next wave: accept comma-separated ranges, and truncate long claims to a headline plus body instead of downgrading.
2. **The reachability lens is systematically the dissenter in a pre-release gem.** Every 2-1 split came from the "reachable from a real entry point" lens voting to refute because no packaged transport exists yet. That lens needs a pre-release calibration: a defect on a public module method of an unreleased gem is not dead code, it is a defect the first consumer inherits on day one. Cap it at P2 by rule if you like, but do not let it refute.
3. **Zero refutations is not the same as a proven verifier.** The 2026-06-11 IEP wave killed 3 of 12; this one killed 0 of 18. The pre-seeded `facts.json` (known failures, out-of-scope list, verified facts) is the likely reason lanes did not overreach. Keep the seeding, and keep the three-lens design even when it looks redundant; the split votes are where the judgment actually happened.
4. **Independent lane convergence is a cheap confidence signal.** The F1 regression was found by three lanes, the open-door identity gate by two, dead half-published surfaces by six. When lanes with different personas land on the same file, the finding is real before any refuter runs.
5. **The ledger and the bead docket must be reconciled in the same pass.** F10 came out "close-now" from the bead auditor and "open" from lane X1 in the same run, and both were right about different documents. Next time, hand the bead auditors the lane outputs before they disposition council-fix beads.
6. **Repros must be `;`-chained, not `&&`-chained.** f-x1-1's repro short-circuited on a zero-match `rg` and printed nothing; a verifier had to rerun it in pieces. A repro that proves absence needs to survive a non-zero exit.
7. **A docs truth pass has to run the examples, not read them.** PR #53 corrected the README's headline claims and left three config examples (`introspection.access_policy_path`, `admin_tools.cache_adapter`, `capability_gate.capabilities_path`) that configure nothing. Executing each README snippet in a fresh `bundle exec ruby -e` would have caught all three.
8. **Pin the worktree to the base SHA for the whole wave.** HEAD advanced four commits mid-wave; every verifier had to prove the files were unchanged. Run lanes and refuters in a worktree checked out at `339453f`.
9. **Lane grades should not be recomputed after verification.** The grades in section 3 are the lanes' own; the verifiers changed severities, not grades. Recording both keeps the review record honest about what each layer concluded.

## 9. Pointers

- Companion data: `010a-RA-REVW-review-wave-findings-and-bead-docket-2026-08-25-data.json` (this record's source; per-lane summaries, council-fix observations, dead-code and doc-drift lists, all 89 findings with votes and gate reasons, the full 36-bead docket). Scratchpad copy at `/tmp/claude-1000/-home-jeremy-000-projects-wild/0a40cdc2-9a72-4a21-93b8-96564317b0af/scratchpad/010a-review-wave-data.json`; files at `000-docs/010a-review-wave-data.json` on merge.
- Pre-seeded facts handed to every lane: `/tmp/claude-1000/-home-jeremy-000-projects-wild/0a40cdc2-9a72-4a21-93b8-96564317b0af/scratchpad/facts.json` (base SHA, out-of-scope list, known-and-already-fixed, 13 verified facts, namespace counts, council ledger, 36 open beads, allowed repro prefixes).
- Plan of record: `000-docs/009-PP-PLAN-strategic-review-and-fix-wave-2026-08-25.md` (stages, cluster rules, evidence bar, definition of done).
- Stage 1 pre-flight PRs on `jeremylongshore/wild`: #51 (`Gemfile.lock` committed, lint fixed under the locked RuboCop, `ci-ok` fan-in, commit `b4f80d3`), #52 (retention fixtures relative to `Time.now.utc`, wall-clock bound dropped from the permission scale spec, `993cebc`), #53 (docs truth pass: README status block, phantom CLI removed, gemspec executables dropped, root `schemas/` deleted; merged as `339453f`, recorded as #55 in `facts.json`).
- Council ledger source: `build-orchestration/STATUS.md` (workspace, untracked, dated 2026-06-01) as captured in `facts.json` `council_fix_ledger_status_md`; council verdict `wild-rails-ai-ops/000-docs/013-AT-AUDT-thinker-council-verdict-rev2-2026-05-29.md`.
- Pattern source for this record's shape: `intent-eval-lab/000-docs/051-AA-AACR-umbrella-review-and-fix-wave-2026-06-11.md` and its `051a` data companion.
- Next document: `011-AA-AACR-...` (after-action report) at Stage 4, when this record flips to FINAL.
