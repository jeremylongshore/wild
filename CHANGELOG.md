# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Per-namespace changes are tracked under their own subsections so each namespace can
SemVer-stamp independently inside the single-gem package (council rev2 concession to
defense Point 3). When a namespace earns its own gemspec under
[ADR-0002](000-docs/adr/ADR-0002-namespace-extraction-policy.md), its CHANGELOG
section splits into a separate file.

## [Unreleased]

### Repo

- **Minimal `spec/dummy/` Rails host app added** (review wave, findings f-x2-1, f-x2-2). `packwerk check` and `brakeman` were crashing outright ("A Rails application could not be found") with no app for either to introspect; `spec/dummy/` is the smallest possible Rails app (railties + action_controller only, no active_record: reconnecting it would wipe the in-memory sqlite fixtures the introspection specs already set up in the same rspec process) that mounts `Wild::Engine` at `/wild` and points Packwerk's Zeitwerk autoload paths at `lib/`. A delegating root `config/environment.rb` exists only because Packwerk hardcodes that path relative to `packwerk.yml`'s directory (the repo root); the real app config lives under `spec/dummy/config/`. `brakeman` is a blocking CI step (`-p spec/dummy`). `spec/engine/engine_spec.rb` boots the dummy app and asserts `Wild::Engine` is an isolated engine mounted at `/wild` and that `Wild.config` exposes all ten namespace accessors. `packwerk check` initially stayed informational (465 namespace-dependency violations); see the follow-up bullet below for the fix that makes it a blocking check too. Advances bead "Ship rails g wild:install generator and pass the 5-minute stopwatch test".
- **Packwerk boundary lane made real and blocking** (review wave, follow-up to f-x2-1/f-x2-2). The 465 violations spec/dummy/ exposed were two distinct, mechanical shapes: (1) 437 forward violations, every namespace package referencing root-substrate constants (`Wild::Error` subclasses, `Wild.config`, `Wild::Configuration`, `Wild::Engine`) without declaring `dependencies: ["."]`, fixed by adding that declaration to all ten `lib/wild/<namespace>/package.yml` files (also fixed: their existing intra-tier `dependencies:` entries used a `"../hooks"`-style relative-to-self syntax that never matched Packwerk's root-relative `Package#name`, so declared edges like admin_tools depending on hooks were silent no-ops; rewritten to root-relative paths like `"lib/wild/hooks"`, now actually enforced); (2) 28 reverse violations, the ten `lib/wild/<namespace>.rb` entry files (each namespace's own require-aggregation-plus-factory-method file, e.g. `Wild::Skillops.build`) sitting in the root package by Ruby's file-per-module convention while wiring their own namespace's internals. Declaring that as a root package.yml dependency was rejected because Packwerk dependencies are package-wide, not per-file: it would let every other root file reach into that namespace too. Excluded the ten entry files in `packwerk.yml` instead, the same treatment the five engine-substrate files already had. `bundle exec packwerk check` is now 0 offenses; `boundary` in `ci.yml` and `release.yml` are blocking, `ci-ok` needs `boundary`. Advances bead "Ship rails g wild:install generator and pass the 5-minute stopwatch test". **Corrected below** (review wave, 2026-08-25): the "1) 437 forward violations…fixed by adding `dependencies: ["."]`" framing was wrong: the five engine-substrate files those constants live in were STILL excluded from `packwerk.yml` after this bullet landed, so the `"."` edge had nothing to resolve against and produced zero forward violations either way; see the next bullet for what was actually true.
- **Fix the paired verifier's three follow-up findings on the boundary lane** (review wave, findings f-x2-1, f-x2-2, f-x2-5, PR #72). Three separate problems, one commit: (1) `brakeman -p spec/dummy` scanned only the empty dummy host app (0 controllers/models) and never parsed `lib/wild/**`, so a planted `system(...)` call in `lib/` would have passed clean; both `ci.yml` and `release.yml` now run `brakeman --force -p . --skip-files spec/`, verified against a planted `eval(code)` probe in `lib/wild/` (flagged, then removed) before landing. (2) `packwerk validate` had never been run: it fails outright on `enforce_privacy` (unknown key on the plain `packwerk` gem this repo depends on; that key needs `packwerk-extensions`), so all eleven `package.yml` files silently claimed a privacy enforcement Packwerk was never going to perform. Chose removing the keys plus correcting `CONTRIBUTING.md`, `ADR-0003`, and `tests/TESTING.md` to say privacy is convention-only over adding `packwerk-extensions` as a new dev dependency: same outcome (`packwerk validate` now passes and is a required `boundary` job step), no new gem to maintain. Adopting `packwerk-extensions` to make `enforce_privacy` real is a follow-up, not done here. (3) The prior bullet's "437 forward violations fixed by declaring `dependencies: ["."]`" was wrong: the five engine-substrate files (`lib/wild.rb`, `engine.rb`, `configuration.rb`, `error.rb`, `version.rb`) were still excluded from `packwerk.yml` at that point, so the `"."` edge in every namespace's `package.yml` was dead configuration with nothing to resolve against, and `packwerk check` staying green was not evidence the edge worked. Un-excluded those five files; `packwerk check` is still 0 offenses, now with the `"."` edge doing real work governing ~750 substrate references. The ten `lib/wild/<namespace>.rb` entry files remain excluded (investigated collapsing them into thin require-only shims with module-level API moved to a namespace-owned `Facade`, found mechanical for one small namespace but not something to carry across all nine remaining entry files (609 lines) plus call sites in one commit); documented as a known enforcement hole in `packwerk.yml`'s "KNOWN ENFORCEMENT HOLE" comment and `ADR-0003`'s 2026-08-25 amendment: a boundary violation reachable only through one of those ten entry points is still invisible to CI. Also: `wild.gemspec` excludes `config/` from `spec.files` (the packwerk-only root `config/environment.rb` shim was shipping in the released gem); `spec/dummy/config/application.rb` was on `config.load_defaults 8.1` against a `rails >= 7.1` gemspec floor (now `7.1`) and relied on `Rails.root` coincidentally equaling `Dir.pwd` (Rails' `find_root` looks for `config.ru`, which doesn't exist anywhere in this tree, not a `Gemfile` as the old comment claimed; `config.root` is now set explicitly); `spec/dummy/config/boot.rb` now pins `RAILS_ENV=test` so `rspec`, `packwerk`, and `brakeman` all boot the same dummy-app environment; the now-unreferenced `spec/dummy/config/database.yml` (active_record/railtie is deliberately never required) is deleted along with its dead `config.paths["config/database"]` entry. Follow-up not done here: adopt `packwerk-extensions` for real `enforce_privacy`; collapse the ten namespace entry files into thin shims to close the module-level-API enforcement hole. Advances bead "Ship rails g wild:install generator and pass the 5-minute stopwatch test".
- **Review-wave record filed** (`000-docs/010-RA-REVW-review-wave-findings-and-bead-docket-2026-08-25.md` + `010a` data.json, DRAFT until Stage 4). Twelve read-only review lanes over every namespace at `339453f`, a scripted evidence gate, three-lens adversarial verification of every P0/P1, and a docket over all 36 non-closed beads: 89 raw findings, 14 confirmed P0/P1 (1 P0: pipeline `Redactor` leaves `turn.metadata` unredacted), 12-lane namespace health, the 13-row council-fix ledger delta (F1 regressed, F2 closed narrowly, F4 closed vacuously, MIN-Armstrong regressed in capability_gate), 12 proposed fix clusters, 11 decisions for the owner. Beads: 3 closed as already done, 5 re-scoped, 4 carry decision notes. Closes beads "Run the twelve-lane review panel…", "Adversarially verify every P0 and P1 finding…", "Audit all thirty-six open and in-progress beads…", "Apply the bead dispositions one at a time…".
- **Docs truth pass for 0.0.1** (review-wave pre-flight, 2026-08-25). README gains a status block saying what works and what does not (generator stub, MCP bin stubs, no `prompts/`, no `wild` CLI, old repos not yet archived); the phantom `bundle exec wild analyzers:…` block is removed. `wild.gemspec` no longer declares the two stub bins as executables. Root `schemas/` (three `.keep` files; the real schemas live at `lib/wild/schemas/`) is deleted and dropped from the Codecov ignore list. `000-docs/000-INDEX.md` (site-map), `000-AA-TMPL` (canonical AAR template copy), and `009-PP-PLAN-strategic-review-and-fix-wave-2026-08-25.md` (plan of record for the review interlude) are filed; `006-OD-STAT` is reconciled to the 2026-06-02 pause + the interlude. PR template extended to the full lane. Closes bead "Make the README, gemspec, and both status pages say what ships today" + "File the review-wave plan, the docs index, the AAR template, and the full-lane PR template".
- **Retention and scale specs made wall-clock independent** (#52). `retention_manager_spec` fixtures are computed relative to now (a hardcoded 2026-03-19 fixture had aged past the 90-day window on 2026-06-17 and turned 6 examples red); the permission `edge_cases_spec` 500×200 example drops its `elapsed < 5.0` bound and asserts report shape instead. Suite green on three seeds. Closes beads "Compute the retention spec fixtures relative to now so they stop aging past the window" + "Drop the wall-clock bound from the permission scale spec and keep it as a shape test".
- **`Gemfile.lock` committed; lint fixed under RuboCop 1.90; `ci-ok` fan-in job** (#51). The untracked lock let CI resolve newer cops than local and Lint was red on every Dependabot PR. `.rubocop.yml` moves to `plugins:` and disables the new `Style/DirectiveScope` cop with a reason. `ci-ok` (`needs: [lint, security, test]`, later extended to include `boundary`, see below) is the single required status for branch protection on `main`. Closes bead "Commit Gemfile.lock, fix lint under the locked RuboCop, and add the ci-ok fan-in job".
- **Review-wave epic tree filed** (`cc47023`): top-level epic "Run a strategic review and fix wave on the wild engine gem before resuming the build" (GH #47) with four stage epics and 14 children.
- Pre-move coupling survey at `000-docs/008-AT-AUDT-pre-move-coupling-survey.md`. Static analysis of all 10 old `wild-*/lib/` trees against ADR-0003. **Finding: zero runtime cross-namespace constant coupling + zero cross-gem require statements.** Structural duplication (F1/F6/Wild::Hooks substrate emergence) identified and filed as 6 beads under their parent namespace epics: `wild-rvv.6.1` (MCP server scaffold → `Wild::Hooks::McpServer`), `wild-rvv.6.2` (audit-logging → `Wild::Hooks::Audit`), `wild-rvv.4.1.3` (capability_gate event.rb ↔ audit_event.yml), `wild-rvv.7.2` (coverage_analyzer dedup), `wild-rvv.5.4` + `wild-rvv.8.3` (F6 exporter audit). Role 5 entry checklist. Closes Role 4 PR-E.
- CONTRIBUTING.md § "Namespace-boundary discipline" expanded to cover the full ADR-0003 enforcement workflow: `# @api private` YARD discipline; new-public-symbol workflow (CHANGELOG + spec + CODEOWNERS); new-inter-namespace-edge workflow (ADR-0003 amendment); new-top-level-namespace workflow (ADR-0001 amendment); Packwerk-violation symptom-fix table; note on `lib/wild/schemas/` as the shared-data substrate. Role 4 PR-F.
- Schemas-as-data substrate landed under `lib/wild/schemas/`. Two files: `wildcard_corpus.yml` (F4 — shared wildcard matching corpus consumed by `Wild::Analyzers::Permission` AND `Wild::CapabilityGate`; 8 documented wildcard forms with `matches` + `non_matches` truth tables) and `capability_gate/audit_event.yml` (F2 — JSON Schema draft 2020-12 for the audit event shape; closed object with 8 required fields including the outcome enum `[allow, deny, evaluation_error]`). Specs verify structure + key fields; full matcher behavior + audit emission lives with Role 5/6. Closes F4 design portion (`wild-rvv.1.2`). Role 4 PR-D.
- `Wild::Error` consumer-distinguishable hierarchy: per-namespace `Wild::<Namespace>::Error` base + targeted subclasses (`CapabilityGate::{DeniedError,PolicyError,EvaluationError}`, `Introspection::{ForbiddenError,ModelNotAllowedError}`, `AdminTools::Error`, `Telemetry::Error`, `Hooks::Error`, `Analyzers::Error`, `Skillops::Error`). Matches `000-docs/003-AT-ARCH-architecture.md § Error hierarchy` verbatim. Closes MIN-Armstrong (`wild-rvv.1.3`). Role 4 PR-C.
- Typed `Wild::Configuration` nested accessors with declared settings classes per namespace (`Introspection`, `AdminTools`, `CapabilityGate`, `Telemetry::{Collector,Pipeline,Analysis}`, `Hooks`, `Analyzers::{Permission,TestFlakes}`, `Skillops`); replaces the `OpenStruct`-based `method_missing` stub. Closes F1 design + initial implementation (`wild-rvv.1.1`). Per-namespace defaults: `on_evaluation_error: :hard_fail` (F2-mandated), `skillops.enabled: false` (F5), `telemetry.analysis.gap_threshold: 0.7`, etc. Role 4 PR-B.
- Initial project setup with full governance (README, LICENSE, CODE_OF_CONDUCT, CONTRIBUTING, SECURITY, SUPPORT, CLAUDE.md, AGENTS.md, EditorConfig, gitattributes)
- CI workflow (Ruby 3.2 + 3.3 + 3.4 matrix; RSpec, RuboCop, Packwerk, brakeman, bundler-audit; Codecov upload)
- Release workflow (workflow_dispatch only — no auto-release on push; v0.1.0 ships at end of the 4-week consolidation build)
- CodeQL static analysis workflow (`security-extended` suite on `ruby` + `actions`; weekly schedule; repo-specific `.github/codeql/codeql-config.yml`); strategy documented at `000-docs/007-AT-STND-codeql-strategy.md`
- Dependabot for bundler + GitHub Actions
- Issue templates (bug, feature) + PR template
- CODEOWNERS, FUNDING
- Ruby gem skeleton: `wild.gemspec`, Gemfile, Rakefile, `bin/console`, `bin/setup`
- Engine skeleton: `lib/wild.rb`, `lib/wild/engine.rb`, `lib/wild/version.rb`, `lib/wild/error.rb`, `lib/wild/configuration.rb`
- Namespace directory placeholders under `lib/wild/`
- ADR-0001 (topology — one gem, ten namespaces)
- ADR-0002 (namespace extraction policy)
- ADR-0003 (namespace dependency graph — four-tier DAG; Role 4 PR-A)
- Root `package.yml` + ten per-namespace `package.yml` files encoding the ADR-0003 dependency contract; `packwerk.yml` lists each package path
- 6-doc enterprise planning set under `000-docs/`

### Wild::Introspection

- Moved 23 source files from `wild-rails-safe-introspection-mcp/lib/wild_rails_safe_introspection/`
  into `lib/wild/introspection/` under the `Wild::Introspection::*` namespace
  (Role 5 PR-11). Sub-directories preserved: `identity/`, `guard/`, `adapter/`,
  `audit/`, `server/` (+ `server/tools/`). Module Zeitwerk-rewritten from
  compact form. New loader at `lib/wild/introspection.rb` carries the
  `.configure` / `.configuration` / `.reset!` accessors from the old gem entry.
- 30 specs (unit + safety + adversarial + integration) moved to
  `spec/wild/introspection/`. The gem tests against a live in-memory
  ActiveRecord schema — `spec/spec_helper.rb` now establishes a throwaway
  sqlite connection and loads the moved `test_schema` + `test_models` (global
  but harmless to non-AR namespaces). `TestConfigHelper` rewrapped as
  `Wild::Introspection::TestSupport::TestConfigHelper` and included +
  `Wild::Introspection.reset!` / `ConnectionManager.reset!` before-hook both
  `file_path`-scoped to introspection specs. Access-policy fixtures moved to
  `spec/support/wild_introspection/fixtures/`.
- **Configuration kept as a namespace object, NOT folded into the central
  struct** (`wild-rvv.u16`). The gem's `Configuration` is a YAML policy loader
  (`access_policy.yml` → per-model blocked columns / allowed models), not a
  settings bag — collapsing it into `Wild::Configuration::Introspection` would
  be a behavior change. It moves as `Wild::Introspection::Configuration` with
  the `.configuration` accessor preserved; wiring the central typed struct's
  `access_policy_path` into this loader at engine boot is a deferred Role 6/8
  task (parallels admin_tools' `wild-rvv.3.1` adapter resolution). F1 still
  holds — F1 closed the nine *settings-bag* singletons, which this is not.
- **MIN-Armstrong — `Wild::Introspection::Error` subtree extended** with the
  gem's `ConfigError`, `WriteAttemptError`, `QueryTimeoutError` (alongside the
  PR-C `ForbiddenError` + `ModelNotAllowedError`). The gem's bare
  `Error < StandardError` is replaced by `Wild::Introspection::Error <
  Wild::Error` — still a StandardError descendant, so consumer rescue behavior
  is preserved. `version.rb` deleted (F1); `server_factory` + `audit_record`
  metadata `version:` → `Wild::VERSION`.
- **NOT in this PR** (deferred per Beck Tidy-First / anti-scope): refactoring
  `server/` to consume the `Wild::Hooks::McpServer` substrate and wiring the
  `bin/wild-mcp-introspection` entry point are Role 9 (MCP/AI-seams); wiring
  the gem's `Identity::CapabilityGate` *stub* to the real `Wild::CapabilityGate`
  is a behavior change for a follow-up. The `server/` code moves verbatim.

### Wild::AdminTools

- **Closed the two_phase guard-chain bypass, made nonce denial responses opaque, and merged policy defaults into every action** (review wave, findings f-l10-4, f-l10-5, f-l10-6). `AuditedPipeline` no longer delegates `:two_phase`, removing an unused PUBLIC handle so an untrusted caller cannot reach `TwoPhaseFlow#confirm_and_execute` through it (this is not a defense against in-process code, which already runs with `Guard::Pipeline`'s privileges regardless of what is delegated (see the trust-boundary note in `lib/wild/admin_tools.rb`); the sanctioned path for every caller, trusted or not, is `#call` (`Guard::Pipeline#call` / `AuditedPipeline#call` / `Server::ToolHandler`), which alone runs the allowlist, param validation, rate limit, blast-radius check, and audit record before a mutation reaches an executor. `ResponseFormatter#denied_hash` drops `:internal_reason` from the client-facing body (it stayed inside a splat despite `NonceManager`'s own opaque-failure doc comment, so not_found/expired/already_used/mismatch were distinguishable to the caller); `Recorder` now prefers `internal_reason` for the audit trail's `denial_reason` so the granularity moves server-side instead of disappearing. `PolicyConfig` merges the `defaults` section's inheritable keys (`rate_limit`, `blast_radius_cap`, `nonce_ttl_seconds`, never `requires_confirmation`, which every action must always declare explicitly) into each action hash at load time (explicit per-action keys still win) instead of only validating it and never using it, so an action that omits `rate_limit` or `blast_radius_cap` inherits the default instead of crashing `RateLimiter`/`BlastRadiusEnforcer` with `NoMethodError`/`ArgumentError` the first time it runs. Advances bead "F6: Audit and either wire or delete every half-published API surface across the namespaces".
- **Security-review follow-up on the above (PR #73): validate merged policy actions against hard ceilings, and deny rather than raise on a missing cap.** `PolicyConfig` was validating the RAW action hash before merging in `defaults`, so an over-ceiling `defaults` section (e.g. `blast_radius_cap` above `max_blast_radius`) loaded clean and silently handed every action that omitted its own cap an over-ceiling value at enforcement time; `defaults` is now checked against `hard_ceilings` at load time too, an explicit-nil action key (the `rate_limit: ~` YAML idiom) is treated as absent rather than as an override, only the three truly-inheritable keys are ever pulled from `defaults` (a stray key like a misplaced `parameters:` in `defaults` is now a load-time error, not a silent no-op), and `config.categories[...]["actions"]` now holds the same merged hashes as `config.action(name)` instead of the pre-merge raw ones. `BlastRadiusEnforcer`/`RateLimiter` deny (not raise) on a `nil`/malformed cap or rate limit as defense in depth. `Result::AUDIT_ONLY_METADATA_KEYS` is now the one shared constant `ResponseFormatter` (stripped from every status, not just `:denied`) and `Recorder` both read, so the two can't drift apart. Closes bead "Validate merged policy actions against hard ceilings and deny on a missing cap".
- Moved 39 source files from `wild-admin-tools-mcp/lib/wild_admin_tools_mcp/`
  into `lib/wild/admin_tools/` under the `Wild::AdminTools::*` namespace
  (Role 5 PR-12 — **the final namespace move; completes the 10-namespace
  consolidation**). Sub-directories preserved: `executor/` (+ `adapters/`),
  `guard/`, `confirmation/`, `audit/`, `identity/`, `server/` (+ `tools/`).
  Module Zeitwerk-rewritten from compact form. New loader at
  `lib/wild/admin_tools.rb` carries the `.configure` / `.configuration` /
  `.reset_configuration!` accessors.
- 39 specs (unit + safety + adversarial + integration) + 5 support files
  moved to `spec/wild/admin_tools/` and `spec/support/wild_admin_tools/`.
  `PolicyFixtures` + `SafetyHelpers` included `file_path`-scoped; a scoped
  `Wild::AdminTools.reset_configuration!` before-hook; `shared_examples`
  required globally. Three specs' stale `require_relative '../../support/test_gate'`
  lines removed (spec_helper loads support globally now).
- **MIN-Armstrong — `Wild::AdminTools::Error` subtree** built with the gem's
  custom-initializer errors: `ActionNotFoundError` (carries `action_name`),
  `ValidationError` (carries `errors`), `AdapterError` + `GateError` (carry
  `original_error`), `AuthenticationError`. The gem's bare `Error < StandardError`
  becomes `Wild::AdminTools::Error < Wild::Error` (rescue behavior preserved);
  its `ConfigurationError` subsumed by `Wild::ConfigurationError`. `version.rb`
  deleted (F1); `audit/record` + `server_factory` version metadata →
  `Wild::VERSION`.
- **Configuration kept as a namespace object** (`wild-rvv.uku`). The gem's
  `Configuration` holds dependency-injection points (`cache_adapter`,
  `job_adapter`, `flag_adapter`, `gate`, `policy_path`, `audit_log_path`,
  `audit_store` — all nil-default). It moves as `Wild::AdminTools::Configuration`
  with the `.configuration` accessor preserved. Reconciling these nil-default
  injection points with PR-B's central `Wild::Configuration::AdminTools`
  `:default` sentinels — **the "kill the DI container" adapter-defaulting at
  engine boot** — is deferred to Role 8 (overlaps `wild-rvv.3.1`). Mirrors the
  introspection `wild-rvv.u16` decision; F1 still holds.
- **NOT in this PR** (anti-scope): refactoring `server/` to consume
  `Wild::Hooks::McpServer` + wiring `bin/wild-mcp-admin` is Role 9 (MCP
  transport); the DI-container adapter-defaulting is Role 8. The `server/`
  code + the `gate`-injection wiring move verbatim.

### Wild::CapabilityGate

- **Review wave: closed four audit-blind paths in the capability gate**
  (findings f-l08-1, f-l08-2, f-l08-3, f-l08-4). Advances bead "Move
  wild-capability-gate into Wild::CapabilityGate and fix the F2 audit-blind
  path"; does not close it (the fail-closed posture for a dark writer+logger
  on an ALLOW result is a separate, deliberately deferred decision, tracked by
  bead "Decide the fail-closed posture for ALLOW results when both the audit
  writer and logger are dark").
  - **f-l08-1**: a hostile (non-Hash) `context` argument to `Gate#evaluate` /
    `Evaluator#evaluate` used to raise `TypeError` inside `Audit::Event#initialize`,
    get swallowed by `emit_audit`'s rescue, and leave the evaluation's ALLOW/DENY
    with zero audit lines. New `SafeCoercion#safe_context` coerces defensively
    (never raises) before event construction, so one bad argument can no longer
    suppress the audit record for its own decision.
  - **f-l08-2**: `Audit::SchemaValidator` already raised `Wild::ConfigurationError`
    when validation was enabled but `json_schemer` (a dev-only dependency) was
    absent, but `emit_audit`'s blanket `StandardError` rescue caught it anyway,
    and with `audit_logger` nil by default the whole thing vanished: every
    evaluation returned ALLOW with zero audit and zero log. `ConfigurationError`
    is now re-raised alongside `AuditSchemaError`, ordered before the
    `StandardError` rescue in both `Evaluator#evaluate` and `Gate#evaluate`, so
    a missing dev dependency fails loudly at first use instead of degrading the
    gate's audit trail. The `:auto` validation toggle's dev/test-on,
    production-off semantics are unchanged.
  - **f-l08-3**: `Gate#evaluate`'s blanket `StandardError` rescue was silently
    swallowing the `AuditSchemaError` that `Evaluator#evaluate` deliberately
    re-raises to surface a non-conforming audit event as a developer bug,
    demoting it to an audit-blind `:evaluation_error` denial. `gate.rb`'s
    comment, and a `gate_spec.rb` example, both asserted this rescue was
    unreachable today (false: the re-raise already existed). Added an
    explicit `rescue AuditSchemaError, ConfigurationError; raise` above the
    blanket rescue, corrected both the comment and the spec's claim, and added
    a Gate-level example proving the raise now reaches the caller.
  - **f-l08-4**: `log_audit_failure` logged to `Wild.config.audit_logger.error`
    only when a logger was explicitly configured; the default `nil` logger made
    every audit-writer failure terminally silent while the gate still returned
    ALLOW/DENY. It now falls back to `Kernel#warn` ($stderr) whenever no usable
    logger is configured (or the configured one itself raises), so a writer
    failure is observable out of the box, not only when a caller opts in.
- **Review-wave verifier follow-ups on the f-l08-1..4 fix (findings f-l08-1,
  f-l08-2, f-l08-3, f-l08-4, PR #74 verifier pass).** Advances the same bead
  ("Move wild-capability-gate into Wild::CapabilityGate and fix the F2
  audit-blind path").
  - **f-l08-4 correction**: `Kernel#warn` is a no-op when `$VERBOSE` is nil
    (`ruby -W0`, a caller wrapped in `silence_warnings`) — the prior fix's own
    specs only passed because `spec_helper.rb` sets `config.warnings = false`,
    which affects RSpec's own noise, not `$VERBOSE`. `log_audit_failure` now
    writes directly to `$stderr`, so the fallback is unconditional; only an
    unwritable `$stderr` defeats it (the CHANGELOG entry above is now true as
    written, not just under the process's default warning verbosity).
  - **f-l08-2 in production**: `SchemaValidator.enabled?`'s `:auto` branch now
    consults `Rails.env` (forcing validation off in a real Rails production
    environment) before falling back to `Wild.config.environment`, closing the
    gap where nothing wires `Wild.config.environment` from `Rails.env` and a
    production app without the dev-only `json_schemer` gem would otherwise
    raise on every evaluation. `Gate#initialize` also probes the validator at
    construction time (when `audit_log_path` is given), so the failure surfaces
    at boot instead of first `#evaluate`; the first-use raise inside
    `SchemaValidator#schemer` remains as a backstop.
  - **f-l08-3 in admin_tools**: `GateClient#authorize` used to rescue every
    `StandardError` (including the deliberately re-raised
    `AuditSchemaError`/`ConfigurationError`) into a `GateError`, and
    `AuthenticatedPipeline` only rescues `GateError`, so a developer-bug signal
    from the gate was indistinguishable from an ordinary denial and its message
    was discarded. `GateClient` now re-raises `CapabilityGate::DEVELOPER_ERRORS`
    members unwrapped (logging the class + message first), so they propagate
    through `AuthenticatedPipeline` instead of becoming a silent `gate_denied`.
  - **f-l08-1 context handling moved and hardened**: context coercion moved
    from `Evaluator`'s `SafeCoercion` into `Audit::Event.coerce_context` (both
    a public class method `Evaluator#evaluate` calls once, up front — so the
    SAME coerced context reaches prerequisite checkers and the audit trail,
    instead of the checker seeing the raw hostile value while the trail
    recorded a separately-coerced one — and a private instance-level backstop
    for any other `Event.new` caller). It now `dup`s a Hash argument before
    freezing (previously `Hash(context)` returned the CALLER's own Hash for a
    real Hash argument, and freezing it was a `FrozenError` trap for any
    consumer who reused that Hash); dispatches the non-Hash placeholder by
    class instead of a blanket `#inspect` (a multi-megabyte String or a very
    deeply nested Array made `#inspect` slow or fatal — a deep Array's
    recursive `#inspect` raises `SystemStackError`, which is not a
    `StandardError` and would have escaped every rescue with zero audit lines
    written); routes the placeholder through `Wild::Hooks::Audit::Sanitizer`
    so a hostile `context: "token=sk-..."` is redacted, not written verbatim;
    and bounds a Hash context that coerces cleanly but is not JSON-safe (NaN,
    invalid encodings, self-reference) or exceeds the `audit_event.yml extra`
    budget (2 KiB), replacing it with a `{ truncated:, keys: }` summary.
    `JsonLinesWriter#write` also gained its own defense-in-depth rescue for
    unserializable event hashes, writing a bounded stand-in line instead of
    dropping the audit record. Corrects a wrong comment claiming a
    pairs-shaped Array converts via `Hash()` — verified false, every non-empty
    Array raises `TypeError` there regardless of shape.
  - Introduced `Wild::CapabilityGate::DEVELOPER_ERRORS = [AuditSchemaError]`
    and `Wild::CapabilityGate::AuditValidatorUnavailableError <
    AuditSchemaError` (replacing the gem-wide `Wild::ConfigurationError` at the
    json_schemer-absent raise site) so every developer-bug re-raise in this
    namespace is one class check, without also giving a free pass to an
    unrelated `ConfigurationError` a future prerequisite checker might raise.
- **F2 fast-follow: Gate-rescue contract pinned + log-failure hardened**
  (Role 6 PR-8, `wild-wxk`; Armstrong F2 sign-off findings 2 + 4 — **closes the
  F2 epic `wild-rvv.4.1`**).
  - **Finding 2 — Gate-rescue contract test.** `Gate#evaluate`'s outer rescue is
    audit-blind *by construction* (the Gate holds no writer; emission lives in
    the Evaluator). It is safe only because `Evaluator#evaluate` never raises —
    an unguarded invariant. Added a spec proving that when the Gate-level rescue
    fires, it still fails closed with `:evaluation_error` AND **no audit event is
    written** (the missing event is the signal that the Evaluator's contract was
    violated — the F2 hole displaced one layer up). Mechanism note: the finding
    proposed `allow_any_instance_of`, but `Evaluator#initialize` freezes the
    instance and RSpec cannot proxy a frozen object, so a verifying
    `instance_double` swap is the working equivalent.
  - **Finding 4 — `log_audit_failure` hardened.** A pathological exception whose
    `#message` itself raises would have turned a should-have-logged into terminal
    silence. The error *class* is now always logged; the message degrades to
    `<unprintable message>` via a never-raising `safe_message` helper (added to
    the `SafeCoercion` collaborator). Proven: bypassing `safe_message` reddens
    the suite.
- **F2 audit events validated against the published schema at emit time**
  (Role 6 PR-7, `wild-rvv.4.1.2`). Wires a real JSON Schema **draft 2020-12**
  validator (`json_schemer` — the transitive `json-schema` gem from `mcp` only
  does draft-04) against `audit_event.yml`, upgrading the test-time round-trip
  conformance gate (wild-rvv.4.1.3) to per-event runtime validation.
  - **New `Audit::SchemaValidator`** — memoized compiled schema; `validate!`
    raises `Wild::CapabilityGate::AuditSchemaError` (new error subclass) with a
    greppable per-error message; `valid?` returns a boolean; `enabled?` resolves
    the toggle.
  - **Config toggle** `Wild.config.capability_gate.validate_audit_events`:
    `:auto` (default — on in dev/test, off in prod), or `true`/`false` to force.
    Validation cost is real; a non-conforming event is a developer bug we want
    surfaced in dev/test, never in production.
  - **F2-safe wiring**: `Evaluator#emit_audit` validates between build and write;
    an `AuditSchemaError` is **re-raised** (both `emit_audit` and `evaluate` let
    it through, ordered before the `StandardError` rescue) so a non-conforming
    event surfaces loudly in dev/test — while genuine write/IO failures stay
    fail-closed-and-logged. Production (validation off) keeps the exact
    never-raises guarantee. Proven end-to-end: a bogus emitted `outcome` turns
    the suite red.
  - **Schema correctness fix surfaced by the validator**: the `capability`
    field's strict `^[a-z][a-z0-9_.]*$` pattern was **removed** (now an
    unconstrained string). An audit event records the *attempted* capability
    verbatim — a denied malformed/probing attempt (`""`, `"12345"`) must be
    auditable, or the gate cannot audit attacks (a silent-denial hole).
    Registered-capability validity is enforced upstream at definition time by
    `Capability#validate_name`, not on this record-of-an-attempt field.
  - **Note**: the bead's original `audit_emit_ms > 0` liveness clause is
    superseded — wild-rvv.4.1.3 removed that field (Armstrong's causality
    finding); liveness is asserted behaviorally (exactly-one-emission).
- **F2 audit event shape reconciled with the published schema (closes the
  design↔runtime loop)** (Role 6 PR-6, `wild-rvv.4.1.3`; Armstrong F2 + Hickey
  schema-as-data gates, both **APPROVE WITH AMENDMENTS**). The runtime
  `Audit::Event#to_h` and the design JSON Schema (`audit_event.yml`) had drifted
  into mutual disagreement (both spec-locked). Resolved by raising the runtime
  to the corrected published contract (the schema is what downstream audit
  consumers read), not by "code is truth" — unlike the F4 corpus, the schema's
  extra fields are genuine audit-grade value, not fiction.
  - **Naming → contract**: `result`→`outcome` (enum `allow`/`deny`/
    `evaluation_error`; `allowed`/`denied` remapped), `caller_id`→`subject`.
  - **`decision_id`** (UUID v4, per-event correlation handle) + **`rationale`**
    (derived non-empty one-liner) now emitted.
  - **`policy_version`** added: a SHA-256 of the **parsed + normalized**
    capability set (NOT file bytes — a comment/whitespace edit must not change
    the version), resolved once at `Registry` load and frozen, so reading it on
    the audit (incl. rescue) path does no I/O and never raises. Enables audit
    replay against a known policy state. A registry without a fingerprint yields
    an all-zero sentinel that still matches the schema pattern.
  - **`audit_emit_ms` removed** (both reviewers): it measured the time spent
    emitting the event itself — unknowable at the frozen value's construction
    (a causality error), unused by the real liveness spec, and a fact about the
    logging subsystem, not the decision. Liveness stays asserted behaviorally
    (exactly-one-emission per evaluate).
  - **`reason` + `risk_level` + `prerequisites_*` promoted to first-class schema
    fields** (reviewers overrode the initial "bury under `extra`" plan): they are
    the gate's own explanation of its decision — the first thing an incident
    responder reads — and must be schema-validated. Only consumer-open
    `session_id` + `context` live under `extra`.
  - **`capability` pattern fixed** to accept dotted names (`admin.jobs.view`),
    matching the wildcard corpus grammar.
  - **Never-raising total outcome remap**: an unrecognized outcome collapses to
    the `evaluation_error` sentinel instead of raising (Event construction runs
    inside the rescue path — a raise would reopen the F2 silent-denial hole).
    Pinned by a spec; the old `ArgumentError`-on-invalid-result behavior is gone.
  - **Round-trip conformance gate** (Hickey's most-costly finding): real
    `Event#to_h` output is validated against `audit_event.yml` (required keys
    present, no key outside the schema, enum/pattern/minLength conformance) so
    the two shapes can no longer silently re-drift. Proven to bite (a stray
    top-level key → red). Full json-schema-gem validation at emit time is
    `wild-rvv.4.1.2`, which upgrades this structural gate.
- **F2 audit-emission ordering pinned + a residual silent-denial hole closed**
  (Role 6 PR-5, `wild-rvv.4.1.1`; Armstrong F2 gate **SIGN-OFF**):
  - **Ordering spec (the bead deliverable):** the audit-liveness suite proved
    the error event is emitted (count + payload) but not its *ordering*. Added
    examples that pin **emit-completes-before-the-denial-returns** via a
    sequence-recording writer; proven to bite (reorder the rescue to
    return-before-emit → 2 red). The bead's original "re-raise" framing predated
    the shipped fail-closed contract — `evaluate` denies, never raises — so the
    invariant is "emit before the terminal *return*", the same audit-completeness
    guarantee. Spec documents the guarantee is synchronous-writer-scoped (async
    writers need a separate durability invariant — `wild-28y`).
  - **Closed a residual silent-denial path (Armstrong Finding 2, fixed in-PR):**
    a hostile `caller_id` whose `#to_s` raises blew up the first coercion in
    `evaluate`; the rescue then re-coerced the same object in
    `deny_evaluation_error`, **raising a second time inside the rescue handler**
    → `evaluate` propagated an exception with no audit written. Now coerced via
    a never-raising `SafeCoercion` collaborator (`safe_symbol` → `:unknown`,
    `safe_caller_id` → `"<uncoercible-caller-id>"`), so the gate still fails
    closed, still audits, and never raises on malformed input. Pinned by 4 new
    examples.
  - **Doc-truth fixes:** the `CapabilityGate::EvaluationError` docstring no
    longer claims the error is "raised" (it is declared but never raised — the
    gate denies); the inert `on_evaluation_error: :hard_fail` config default now
    carries an inline "CURRENTLY INERT" warning so no operator infers raise
    semantics. Both reconciled under decide-or-cut `wild-28y`. Armstrong's
    dark-audit-ALLOW posture finding filed as `wild-0c3` (P1).
- **F2 audit-emission fix (council rev2, Armstrong)** — closes the two
  audit-blind paths the council named (Role 6 PR-1, `wild-rvv.4.1`):
  - **Evaluation that raises now leaves an audit trail.** `Evaluator#evaluate`
    wraps its decision logic in a rescue: on any `StandardError` it fails
    closed (denies with reason `:evaluation_error`) AND emits the matching
    audit event before returning. Previously a raise propagated to
    `Gate#evaluate`'s rescue, which denied but emitted nothing — a silent
    denial. The prerequisite checkers are already fail-closed, so this is
    defense-in-depth against a corrupted registry/grant or a future checker bug.
  - **Audit-pipeline failure is no longer doubly silent.** `Evaluator#emit_audit`
    previously swallowed write failures to `nil`. It now logs them to
    `Wild.config.audit_logger.error` (still never raises — a broken audit log
    must not break the gate). **Correction (review wave, finding f-l08-4):**
    this guarantee originally only held when a caller had explicitly
    configured `audit_logger`: it defaults to `nil` (`configuration.rb`), so
    a single writer failure under default configuration was terminally
    silent, not merely "a simultaneous writer-AND-logger outage" as stated
    here previously. `log_audit_failure` now falls back to `Kernel#warn`
    ($stderr) whenever no usable logger is configured (or the configured one
    itself raises), so a writer failure is never silent out of the box; only
    an unwritable `$stderr` defeats it.
  - `Audit::Event` gains a third result value, `evaluation_error` (distinct
    from `denied`), so audit readers can tell "policy said no" apart from "the
    gate broke and failed closed". `:evaluation_error` is always a denial
    (hard-fail intrinsic to `EvaluationResult.denied`).
  - New `spec/wild/capability_gate/audit/audit_liveness_spec.rb` (8 examples)
    proves the property under deliberate corruption: an exploding registry →
    asserts denial + reason `:evaluation_error` + exactly one emitted event
    with `result: "evaluation_error"`; an exploding writer → asserts no raise,
    allow-result preserved, and the failure logged to the audit logger.
  - **NOT in this PR** (separate `wild-rvv.4.1` children): the full
    `audit_event.yml` schema migration — `decision_id` / `policy_version` /
    `audit_emit_ms` (`wild-rvv.4.1.3`), and the json-schema validator wiring
    (`wild-rvv.4.1.2`). This PR uses the existing event shape + the new
    `evaluation_error` result value.
- Moved 18 source files from `wild-capability-gate/lib/wild/capability_gate/`
  into `lib/wild/capability_gate/` under the existing `Wild::CapabilityGate`
  namespace. The source gem already used proper lexical module nesting and
  the correct `lib/wild/capability_gate/` path layout, so the move is
  effectively a copy + entry-loader cleanup with no namespace renames.
  Layout preserved verbatim: `audit/`, `evaluator/`, `prerequisites/`,
  `registry/`, `session/` sub-directories. Closes `wild-rvv.4` base move
  (Role 5 PR-4).
- Moved 18 spec files (unit + integration + safety + governance) to
  `spec/wild/capability_gate/{,integration,safety}/`. 11 YAML fixtures
  moved to `spec/fixtures/`. Three specs had their fixture-resolution
  paths updated from `'../fixtures/config'` to `'../../../fixtures/config'`
  to account for the deeper nesting under `spec/wild/capability_gate/`.
- Deleted the duplicate `version.rb` (F1 — gem version is canonical at
  `Wild::VERSION`). Updated `spec/wild/capability_gate_spec.rb` smoke
  test to assert `Wild::VERSION` instead of the removed
  `Wild::CapabilityGate::VERSION`.
- The `Wild::CapabilityGate::Error` hierarchy (DeniedError, PolicyError,
  EvaluationError) already exists from PR-C (MIN-Armstrong) — the moved
  code's three internal error classes (`Registry::DuplicateCapabilityError`,
  `Registry::ConfigLoader::ConfigError`, `Evaluator::GrantLoader::GrantConfigError`)
  remain as-is per Beck Tidy-First (re-parenting them to `PolicyError`
  would be a behavior change for a follow-up).
- F2 audit-blind fix is **explicitly NOT in this PR** — that's `wild-rvv.4.1`
  (Role 6). This PR is the structure-only move that Role 6's behavior
  change lands on top of, per Role 5 doc § "Validation gate".

### Wild::Telemetry::Collector

- **Retention purges made lock-safe and crash-safe, store failures made observable** (review wave, findings f-l02-1, f-l02-2, f-l02-3). `JsonLinesStore` gains `#compact`, which rewrites the file under the same `@mutex` `#append` uses (a 2000-fresh/2000-expired-noise appends racing 300 `purge_expired` calls lost a measurable slice of fresh events without it) and via a temp file fsync'd before an atomic `File.rename` (a rename failure now leaves the original file untouched instead of a half-written truncate). `RetentionManager#purge_before` and `#remove_oldest_until_within_limit` route through it instead of touching `@store.path` directly; a rewrite failure now raises instead of being swallowed into a misleadingly clean `0`. `EventReceiver` keeps its spec-pinned fire-and-forget contract (a store failure still returns `nil`, same as a validation reject) but now counts (`#storage_failure_count`) and logs (`Wild.config.audit_logger`, mirroring `CapabilityGate::Evaluator#log_audit_failure`'s F2 "not doubly silent" pattern) every store failure distinctly, so an ops process can alert on real disk problems instead of a silent, indistinguishable data loss. `Wild::Telemetry::Collector::StorageError` (`lib/wild/error.rb`) is left defined but unraised: it is flagged separately as dead API surface under finding f-l02-5 (out of scope here), and wiring a typed exception into the fire-and-forget path is a bigger API decision the existing adversarial specs already pin against, not something this observability fix should decide unilaterally. Durability framing (fsync-per-append vs. dropping the append-only-log claim) stays with the open decision bead; this fix is required on either horn of that decision. Advances bead "MIN-Kleppmann: Decide fsync per append OR drop append-only audit log framing from telemetry collector".
- **Purge rewrites made permission-safe, store failures now typed, log level raised to :error** (review wave verifier follow-ups, findings f-l02-1, f-l02-2, f-l02-3, f-l02-5). `JsonLinesStore#compact`/`#clear!` now rewrite through ActiveSupport's `File.atomic_write` instead of a hand-rolled temp-file-plus-rename: the replacement keeps the original file's uid/gid/mode (a hand-rolled `File.open(tmp, "wb")` picked up umask-default permissions and the calling uid instead, so a 0600 store could silently become 0664 after its first purge), a stray Tempfile left behind by a failed rename is cleaned up explicitly, and the containing directory is fsync'd best-effort after the rename lands. `#append`, `#compact`, and `#clear!` now wrap `SystemCallError`/`IOError` in `Wild::Telemetry::Collector::StorageError` (cause preserved), retiring the "left defined but unraised" half of finding f-l02-5. `EventReceiver#log_storage_failure` now logs at `:error` via `logger.error`, matching `CapabilityGate::Evaluator#log_audit_failure` exactly instead of `:warn`; `#store_envelope` distinguishes a `StorageError` (counted + logged as a storage failure) from any other `StandardError` (logged separately as an internal error, not counted), so `#storage_failure_count` only tracks genuine store I/O failures. `RetentionManager#remove_oldest_until_within_limit` is now a single pass with a running size subtraction instead of recomputing the kept size on every shift. `#compact`'s docstring now states plainly that its lock is process-local (no flock; cross-process purge/append on a shared file is unprotected) rather than only implying it. Advances bead "Add cross-process file locking to JsonLinesStore for multi-process purge/append safety" (the one thing still open from this cluster).
- Moved 13 source files from `wild-session-telemetry/lib/wild_session_telemetry/`
  into `lib/wild/telemetry/collector/` under the 3-deep
  `Wild::Telemetry::Collector::*` namespace (Role 5 PR-8; first of three
  Telemetry sub-namespace moves — Pipeline + Analysis follow). Sub-directories
  preserved: `schema/`, `store/`, `privacy/`, `collector/`, `export/`,
  `aggregation/`. Module Zeitwerk-rewritten from compact form. New loader at
  `lib/wild/telemetry/collector.rb`. (The gem's internal `collector/`
  submodule nests as `Collector::Collector::EventReceiver` — behavior-preserving;
  any flatten/rename is a deferred behavior change.)
- 17 specs (unit + adversarial + integration) moved to
  `spec/wild/telemetry/collector/`. `EventFixtures` rewrapped as
  `Wild::Telemetry::Collector::TestSupport::EventFixtures`, wired into spec_helper.
- **F1 — `Wild::Configuration::Telemetry::Collector` extended** from 1 setting
  (`enabled` from PR-B) to 5: the 4 old-gem knobs (`store`, `retention_days`
  90, `privacy_mode` :strict, `max_storage_bytes`) plus `enabled`. Defaults
  verbatim. Deleted `version.rb` + `configuration.rb`; orphaned
  `configuration_spec.rb` removed (coverage folded into central config spec).
- **MIN-Armstrong — `Wild::Telemetry::Collector::Error` subtree added**:
  `ValidationError`, `SchemaError`, `StorageError`. Old gem's
  `ConfigurationError` subsumed by `Wild::ConfigurationError`.
- Config setter validation + freeze!/frozen? machinery NOT carried over;
  4 freeze/immutability adversarial specs (doc-005 Rule 8, doc-006 Threat 7)
  deleted per F3 (no vanity tests of absent behavior). Rationale inline.
- Pre-existing complexity in the moved aggregation/export code tripped wild's
  stricter Metrics config — localized inline disables per site (no refactor;
  behavior-preserving move).
- **NOT in this PR** (deferred per Beck Tidy-First, all `wild-rvv.5` children):
  F7 boundary normalization (`5.1`), F8 decomplect identity/value/time (`5.2`),
  MIN-Kleppmann append-only-log fsync decision (`5.3`), F6 export audit (`5.4`).

### Wild::Telemetry::Pipeline

- Moved 16 source files from `wild-transcript-pipeline/lib/wild_transcript_pipeline/`
  into `lib/wild/telemetry/pipeline/` under the 3-deep
  `Wild::Telemetry::Pipeline::*` namespace (Role 5 PR-9; second of three
  Telemetry sub-namespace moves). Sub-directories preserved: `ingestion/`,
  `normalization/`, `privacy/`, `models/`, `export/`. Module Zeitwerk-rewritten
  from compact form. New loader at `lib/wild/telemetry/pipeline.rb` carries the
  `Wild::Telemetry::Pipeline.process` convenience method (full ingest →
  normalize → redact pipeline) from the old gem entry point.
- 19 specs (unit + adversarial + integration) moved to
  `spec/wild/telemetry/pipeline/`. `TranscriptFixtures` rewrapped as
  `Wild::Telemetry::Pipeline::TestSupport::TranscriptFixtures`, wired into
  spec_helper. Spec `WildTranscriptPipeline.process` calls + flat config
  setters rewritten to the nested API.
- **F1 — `Wild::Configuration::Telemetry::Pipeline` extended** from 1 setting
  (`sequence_strategy` from PR-B) to 8: the 7 old-gem knobs
  (`intent_confidence_threshold` 0.5, `max_turn_content_length` 10_000,
  `max_turns_per_transcript` 1_000, `redaction_marker` "[REDACTED]",
  `strip_absolute_paths` true, `strip_file_contents` true, `custom_patterns`
  []) plus `sequence_strategy`. Defaults verbatim. Deleted `version.rb` +
  `configuration.rb`; `json_exporter` metadata `version:` → `Wild::VERSION`;
  orphaned `configuration_spec.rb` removed.
- **MIN-Armstrong — `Wild::Telemetry::Pipeline::Error` subtree added**:
  `IngestionError`, `NormalizationError`, `PrivacyError`, `ExportError`. Old
  gem's `ConfigurationError` subsumed by `Wild::ConfigurationError`.
- Pre-existing complexity (`Transcript` value-object ParameterLists,
  `tool_extractor` AbcSize) handled with localized inline disables — no
  refactor (behavior-preserving move).
- **NOT in this PR** (deferred, `wild-rvv.5` children): F7 (`5.1`), F8 (`5.2`),
  MIN-Kleppmann (`5.3`), F6 export audit (`5.4`).
- **`Redactor#redact_turn` now scrubs `turn.metadata`, not just `turn.content`**
  (review wave, finding f-l03-1). Raw `tool_input`/`tool_output` copied
  verbatim by `ClaudeCodeAdapter` was reaching `Export::JsonExporter` output
  unredacted, so a secret passed as a tool argument survived into exported
  telemetry. New `Redactor#redact_metadata` walks Hash/Array structures
  recursively and redacts String leaves with the same built-in and custom
  `ContentFilter` patterns used for content; keys and non-String values pass
  through untouched. Fixed at the Redactor (the privacy boundary) rather than
  in each adapter, so every ingestion source is covered by one scrub pass
  instead of requiring per-adapter redaction. Advances bead "F7: Add
  boundary normalization wherever data crosses namespaces". Does not address
  the separate JSON-quoted `api_key` pattern gap (f-l03-2), which lands as
  its own PR.
- **Metadata redaction hardened: key-aware, secrets-only, class-preserving,
  bounded, and single-pass** (paired-verifier follow-up on the item above,
  f-l03-1). A Hash key matching a secret-name pattern (`api_key`,
  `aws_secret`, `Authorization`, etc., normalized for case/separators) now
  redacts its whole value regardless of shape, closing the gap where
  `{"api_key" => "sk_live_..."}` exported verbatim because the value itself
  matched no built-in pattern. Metadata leaf scrubbing is now secrets-only
  (API key, AWS key/secret, GitHub token, bearer token, custom patterns);
  it no longer applies the EMAIL/IP/ABSOLUTE_PATH/file-content patterns
  `#redact_content` uses, which were mangling structural metadata like
  `method: "tools/call"`, `tool_name`, `file_path`, and `git@`-style remote
  URLs. `redact_transcript` now scrubs `transcript.metadata` with the same
  rules (it previously passed it through unredacted while stamping
  `redacted: true`). The rebuild preserves the source Hash's class, so
  `ActiveSupport::HashWithIndifferentAccess` metadata keeps working after
  redaction. Recursion is capped at 64 levels with cycle detection, raising
  `PrivacyError` instead of `SystemStackError` on a malformed or
  self-referential payload. `Pipeline.run_pipeline` no longer redacts each
  turn once during normalization and again inside `redact_transcript`; turns
  are redacted exactly once, at export. New `Privacy::MetadataRedactor`
  holds this logic (split out of `Redactor` to stay under
  `Metrics/ClassLength`). Advances bead "F7: Add boundary normalization
  wherever data crosses namespaces".
- **`ContentFilter::API_KEY_PATTERN` and `AWS_SECRET_KEY_PATTERN` now match
  JSON-quoted and hash-rocket secret shapes, not just bare `key=value`**
  (review wave, finding f-l03-2). Both patterns required the key name
  followed by optional whitespace then `:`/`=` directly, so a closing quote
  between the key and the separator, the shape `JSON.generate` and Ruby
  hash literals produce (`"api_key":"sk_live_..."`, `'api_key' => 'sk_live_...'`),
  never matched: `ClaudeCodeAdapter#extract_tool_use_content` builds turn
  content as `name(#{JSON.generate(input)})`, so any tool call carrying a
  secret in its `input` put that secret into content in exactly this
  unmatched shape, past `Export::JsonExporter` unredacted (the turn's
  metadata copy of the same secret was already covered by f-l03-1's
  `MetadataRedactor`, content was not). Both patterns now name a `prefix`
  and `suffix` capture around the secret value, tolerating an optional
  closing quote and whitespace before the separator (`:`, `=`, or `=>`) and
  an optional opening quote after it; `Redactor#redact_pattern` replaces
  only the captured value when those named groups are present (built-in or
  a caller's own key-anchored custom pattern), so `"api_key":"sk_live_..."`
  redacts to `"api_key":"[REDACTED]"` and stays parseable JSON, rather than
  the whole `key:value` span collapsing into a bare marker. `GITHUB_TOKEN_PATTERN`,
  `AWS_ACCESS_KEY_PATTERN`, and `BEARER_TOKEN_PATTERN` needed no change:
  none of them anchor on a key name, so they already matched the token
  value alone inside surrounding quotes. Advances bead "F7: Add boundary
  normalization wherever data crosses namespaces".
- **HIGH regression fixed: derived `Intent#description` leaked secrets past
  the redaction boundary, and `#redact_content` was not idempotent against
  its own marker** (security-review follow-up on the item above, f-l03-1).
  Moving `IntentDetector`/`ToolExtractor` upstream of redaction (the fix
  above) left `Redactor#redact_transcript` passing `transcript.intents`
  through untouched: `IntentDetector#build_description` copies up to an
  80-char verbatim slice of raw turn content into `Intent#description`, so a
  secret in a turn's text (an API key, an IP address) survived into
  `Export::JsonExporter` output even though the turn itself was correctly
  redacted, with `metadata.redacted` reporting `true`. `redact_transcript`
  now maps `transcript.intents` through a new `Redactor#redact_intent`,
  which redacts `description` via `#redact_content` and re-emits an
  `Intent` with `confidence`/`source_turn_index` unchanged; keeps
  `redact_transcript` the single, complete boundary that touches every
  exported field. `tool_references` are left as-is: every extraction
  pattern in `ToolExtractor` constrains captured names to
  `[a-z_][a-z0-9_-]*`, so a name can't carry a secret shape (asserted by a
  new spec, not a code change). Separately, `#redact_content` is now
  idempotent against a redaction marker that happens to match one of its
  own patterns (e.g. an email-shaped marker like
  `<redacted@wild.local>`): it splits the input on the marker string first
  and only pattern-matches the segments between marker occurrences, so a
  future accidental double pass, or any marker shape, can no longer corrupt
  already-redacted text by re-wrapping it. Advances bead "F7: Add boundary
  normalization wherever data crosses namespaces".

### Wild::Telemetry::Analysis

- Moved 25 source files from `wild-gap-miner/lib/wild_gap_miner/` into
  `lib/wild/telemetry/analysis/` under the 3-deep
  `Wild::Telemetry::Analysis::*` namespace (Role 5 PR-10; **completes the
  three-gem `wild-rvv.5` Telemetry epic structure**). Sub-directories
  preserved: `models/`, `ingestion/`, `analyzers/`, `scoring/`,
  `recommendations/`, `report/`, `export/`. Module Zeitwerk-rewritten from
  compact form. New loader at `lib/wild/telemetry/analysis.rb` carries the
  `Wild::Telemetry::Analysis.analyze` convenience method (parse export →
  build gap report) from the old gem entry point.
- 25 specs (unit + adversarial + integration) moved to
  `spec/wild/telemetry/analysis/`. `TelemetryFixtures` rewrapped as
  `Wild::Telemetry::Analysis::TestSupport::TelemetryFixtures`; `HEADER_DATA`
  constant refs + flat config setters rewritten to the nested API.
- **F1 — `Wild::Configuration::Telemetry::Analysis` extended** from 1 setting
  (`gap_threshold` from PR-B) to 9: the 8 old-gem thresholds (`denial_threshold`
  0.2, `failure_threshold` 0.15, `latency_p95_threshold_ms` 500.0,
  `utilization_min_count` 5, `coverage_min_fraction` 0.3,
  `pattern_min_occurrences` 3, `max_gaps_per_type` 50, `severity_weights`
  all-1.0 six-signal map) plus `gap_threshold`. Defaults verbatim from the
  gem's DEFAULTS hash. Deleted `version.rb` + `configuration.rb`; orphaned
  `configuration_spec.rb` removed.
- **MIN-Armstrong — `Wild::Telemetry::Analysis::Error` subtree added**:
  `ParseError`, `ValidationError`, `SchemaError`, `ExportError`. Old gem's
  `ConfigurationError` subsumed by `Wild::ConfigurationError`.
- **Fixture isolation fix** — all per-namespace fixture modules are now
  `config.include`d scoped by `file_path` (not globally). `build_event`
  collided between `Wild::Hooks::TestSupport::HookFixtures` and the telemetry
  `TelemetryFixtures`; global includes let the last-loaded shadow the rest.
  Path-scoping binds each namespace's helpers to its own specs.
- Pre-existing complexity (`coverage_analyzer` AbcSize, `Gap` ParameterLists)
  handled with localized inline disables — no refactor.
- **NOT in this PR** (deferred, `wild-rvv.5` children): F7 (`5.1`), F8 (`5.2`),
  MIN-Kleppmann (`5.3`), F6 export audit (`5.4`). Config validation + freeze
  machinery dropped; 8 validation/freeze adversarial specs deleted per F3.

### Wild::Hooks

- **Audit::Logger routes context through Audit::Sanitizer; Runner isolates its
  observability calls** (review wave, finding f-l01-1 and f-l01-2). Logger#record
  previously formatted context values with raw `v.inspect`, so a password or
  api_key passed as hook context landed verbatim in `context_summary`; it now
  runs every context key/value through the existing (until now unused)
  `Wild::Hooks::Audit::Sanitizer` (an injectable `sanitizer:` keyword defaults
  to `Sanitizer.new`), closing f-l01-1 and, incidentally, f-l01-5 (the
  Sanitizer now has a real caller). Separately, Runner#execute called
  `audit_logger.record` / `health_monitor.record` with no isolation, so a
  raising sink aborted the invocation after the handler had already run; those
  two calls are now wrapped so a raising sink cannot abort the invocation, and
  the failure is recorded visibly (`observability_failures` counter plus a
  warn through `Wild.config.audit_logger`, mirroring the escape hatch
  `CapabilityGate::Evaluator#log_audit_failure` already uses) rather than
  swallowed, per council F2. Advances bead "Extract audit-logging pattern to
  Wild::Hooks::Audit substrate" (ToolHandler wire-or-delete, f-l01-3, remains).

- **Audit substrate extension landed** — closes the structural-duplication
  portion of `wild-rvv.6.2`. Two new classes/modules under the existing
  `Wild::Hooks::Audit` namespace (which already hosts `Trail` + `Logger`
  from PR #20):
  - `Wild::Hooks::Audit::Sanitizer` — generic key-pattern parameter
    sanitizer extracted from `wild-admin-tools-mcp`'s reusable design.
    Configurable `redact_keys` (defaults cover password / secret /
    token / api_key / private_key / ssn / credit_card / email / phone /
    address) and `hash_keys` (defaults: job_id / actor_id / user_id /
    account_id → SHA-256 fingerprint). Recurses into nested hashes,
    does not mutate input. Introspection's per-tool dispatch sanitizer
    stays in `Wild::Introspection::Audit::*` (different shape entirely)
    and can wrap this Sanitizer for its redaction layer when that
    namespace moves.
  - `Wild::Hooks::Audit::Timer` — `Process::CLOCK_MONOTONIC` wrapper
    that both old gems inlined inline at every emission site. Provides
    `.now` + `.elapsed_ms(start)` for measuring `audit_emit_ms` (F2
    audit-liveness metric per architecture doc). Consumed by the F2
    emitter Wild::CapabilityGate will use when wild-rvv.4.1 lands.
  - The two `recorder.rb` files in introspection + admin_tools were
    intentionally NOT pulled up — they're too divergent (hash-result vs
    object-result, swallow-errors vs re-raise, different domain attrs).
    Forcing them together would be a false abstraction.
- **MCP server substrate landed** (`Wild::Hooks::McpServer`) — Tier 1
  transport substrate per ADR-0003. Two public APIs:
  - `Wild::Hooks::McpServer::Factory.create(name:, version:, tools:, server_context: {})`
    consolidates the `MCP::Server.new(...)` boilerplate that lived
    independently in `wild-rails-safe-introspection-mcp` and
    `wild-admin-tools-mcp`.
  - `Wild::Hooks::McpServer::ToolHandler.wrap { ... }` consolidates the
    `rescue StandardError` outer wrapper that both gems' `ToolHandler.execute`
    paths had. Per-namespace identity / capability-gate / pipeline logic
    STAYS in the namespaces; only the rescue + format-via-callback pattern
    is shared (consumer supplies `error_formatter:`).
  - `mcp ~> 0.8` added as a runtime dependency (was already a runtime dep
    in both old gems' gemspecs).
  - Closes the substrate-extraction portion of wild-rvv.6.1. When the
    introspection + admin_tools moves land in their respective Role 5 PRs,
    they will consume this substrate and drop their own duplicates.
- Moved 14 source files from `wild-hook-ops/lib/wild_hook_ops/` into
  `lib/wild/hooks/` under the `Wild::Hooks::*` namespace (Role 5 PR-1).
  Layout preserved verbatim: `models/`, `registry/`, `execution/`,
  `lifecycle/`, `health/`, `audit/` sub-directories with the same files,
  just renamed at the module level. Loader at `lib/wild/hooks.rb` replaces
  the old `wild_hook_ops.rb` entry point.
- 16 specs + 1 integration + 1 adversarial + 1 fixtures module moved to
  `spec/wild/hooks/` and `spec/support/wild_hooks/`. `Wild::Hooks::TestSupport::HookFixtures`
  wired into `spec/spec_helper.rb`.
- Collapsed the old `WildHookOps::Configuration` class into
  `Wild::Configuration::Hooks` (F1). Seven knobs now on `Wild.config.hooks`:
  `default_timeout_ms` (5000), `max_handlers_per_hook` (20), `enable_audit_logging`
  (true), `max_audit_entries` (10_000), `execution_mode` (:sequential),
  `on_handler_error` (:log_and_continue), `lifecycle` (:rails_engine).
  Defaults preserved verbatim from the old gem. The old gem's per-setter
  type validation + `freeze!`/`frozen?` machinery is NOT carried over —
  filed as Role 6 follow-up under wild-rvv.6.
- Collapsed the old `WildHookOps` error tree (6 classes) into the
  `Wild::Hooks::Error` hierarchy (MIN-Armstrong). Four subclasses now under
  `Wild::Hooks::Error`: `HookNotFoundError`, `DuplicateHookError`,
  `HandlerLimitExceededError`, `InvalidHandlerError`. The old gem's
  `InvalidConfigurationError` + `ConfigurationFrozenError` are subsumed by
  `Wild::ConfigurationError` (Wild engine no longer freezes config — by
  design per architecture doc).
- Closes wild-rvv.6 base move. The two children (wild-rvv.6.1 MCP server
  scaffold + wild-rvv.6.2 audit-logging) remain open — they extract shared
  patterns from the introspection + admin_tools gems into this same
  namespace in follow-up PRs.

### Wild::Analyzers::Permission

- **F4 anti-drift fence landed + corpus reconciled to the real grammar**
  (Role 6 PR-3; `wild-rvv.1.2.1` + `wild-lkp`). The shared
  `lib/wild/schemas/wildcard_corpus.yml` (Role 4 PR-D) described a `::`-segmented
  grammar with 8 forms + segment-boundary semantics that **neither shipped
  matcher implemented**, in a notation that doesn't match the real dotted/flat
  capability names. Per the "code is truth" reconciliation:
  - **Corpus rewritten (v1 → v2)** to the dotted-glob grammar
    `Wild::Analyzers::Permission::Analyzers::WildcardMatcher` actually implements
    (exact; trailing `admin.jobs.*`; prefix `admin.*`; middle `admin.*.retry`;
    universal `*`). Truth tables verified against the live matcher's real
    (greedy `*`→`.*`, no segment-boundary) behaviour — `admin.jobs.*` matches the
    deeper `admin.jobs.retry.force`; universal `*` matches every string incl `""`.
  - **New corpus-driven smoke spec** (`wildcard_corpus_matcher_spec.rb`) runs the
    matcher against every entry's `matches[]`/`non_matches[]` — the actual
    anti-drift fence; red if the matcher drifts from the documented grammar.
  - **Escaping-contract rows pinned** (Hickey F4 gate, Finding 1): the corpus now
    pins the grammar's *defining* constraint, not just its happy path — `*` is the
    SOLE metacharacter (every other char is a literal, because `Regexp.escape`
    runs before the `*`→`.*` substitution), and `*` is zero-or-more. Rows for
    `.*` (leading-dot-literal, NOT universal), `a.b`/`a+b` (literal dot/plus),
    `a*c` + `admin.jobs.` (zero-width `*`). Fence verified by mutation: dropping
    `Regexp.escape` → 2 red; `.*`→`.+` → 3 red. Reviewer follow-ups filed as
    `wild-96t` (schema-spec non_matches invariant) + `wild-yms` (centralize
    wildcard *detection*). Schema-as-data seam signed off by `rich-hickey-reviewer`.
  - **Scope decision**: capability-name wildcard matching lives in exactly ONE
    namespace (Permission). `Wild::CapabilityGate` is exact-symbol-match BY
    DESIGN — its only wildcard is the *caller* `*` (a different axis). The
    council F4 "the two must not disagree" is satisfied vacuously — there is one
    capability-name matcher. Documented in `grant.rb` + pinned by new
    `grant_spec` cases. The richer `::` grammar, if ever wanted, is a deliberate
    matcher change with its own ADR — not a silent expectation.
- **`detect_cycle` false-positive fixed** (Fowler review findings 1 + 10 —
  his most-costly-to-recover-from finding; Role 6 PR-2, `wild-jzg` under
  `wild-rvv.7`). `PrerequisiteAnalyzer#detect_cycle` used a
  `depth > max_prerequisite_depth` short-circuit that fabricated a
  `:circular_prerequisite/critical` finding for ANY acyclic chain deeper than
  the limit (default 10) — "a security tool that invents critical findings
  teaches operators to ignore critical findings." It also re-discovered each
  real cycle once per node on it (path-local `visited` + per-node re-entry).
  Replaced with an **iterative tri-color DFS** (WHITE/GRAY/BLACK global state,
  explicit frame stack — no recursion-depth ceiling): a back-edge to a GRAY
  (on-stack) node is the only cycle signal, and each ring is reported exactly
  once via a rotation-invariant signature. The depth limit is gone (it was the
  bug, not a safety feature).
- **`max_prerequisite_depth` config knob removed** (`wild-0e0`, Fowler+Hickey
  decide-or-cut follow-up on the detect_cycle fix). Tri-color DFS left the knob
  wired to nothing. Per the reviewers' own framing — "dead config erodes trust
  in live config; the next operator sets it expecting an effect, gets none,
  distrusts the whole config surface" — it was **cut**, not left inert. Dropped
  the `Wild::Configuration::Analyzers::Permission` struct member + its default,
  the "defaults to 10" + "accepts 1" spec assertions, and the
  "even with the knob set low" cycle-guard variant. A future "warn beyond
  operational depth" finding, if ever wanted, is a clean additive feature (new
  knob + `:warning` finding) under its own bead — not a speculatively-reserved
  hook. CTO call: option (a) delete over option (b) build-the-feature, per the
  "no speculative infrastructure" build principle.
- **Test discipline** (Beck + Fowler gate): the former
  "max_prerequisite_depth prevents infinite loops" example — which built a
  15-deep acyclic chain, set the limit to 5, and asserted only `not_to
  raise_error`, thereby documenting the false positive as a feature — was
  **deleted**. Replaced with: a 15-deep-straight-line guard (zero
  `:circular_prerequisite` findings), 2-node +
  3-node cycle "reported exactly once" specs, a diamond (shared-but-acyclic)
  guard, and a `full_audit_spec` integration test proving a deep acyclic chain
  yields zero critical findings. All written failing-first against the buggy
  code, then green after the fix.
- Moved 17 source files from `wild-permission-analyzer/lib/wild_permission_analyzer/`
  into `lib/wild/analyzers/permission/` under the 3-deep `Wild::Analyzers::Permission::*`
  namespace (Role 5 PR-6). Sub-directories preserved: `models/`, `loaders/`,
  `analyzers/`, `report/`, `export/`. Module rewritten from compact
  `module WildPermissionAnalyzer` to nested `module Wild; module Analyzers;
  module Permission` (Zeitwerk-compatible, same fix as PR #20). New loader at
  `lib/wild/analyzers/permission.rb` carries the `Wild::Analyzers::Permission.audit`
  convenience method from the old gem entry point.
- 22 specs (unit + adversarial + integration) moved to
  `spec/wild/analyzers/permission/`. Fixtures module rewrapped as
  `Wild::Analyzers::Permission::TestSupport::Fixtures`, wired into spec_helper.
- **F1 — `Wild::Configuration::Analyzers::Permission` extended** from 1 setting
  (`cycle_detection` from PR-B) to 6: the 5 old-gem knobs (`capabilities_path`,
  `grants_path`, `risk_levels` four-tier severity map, `wildcard_risk_threshold`
  "medium", `max_prerequisite_depth` 10) plus `cycle_detection`. Defaults
  preserved verbatim. Deleted the old gem's `version.rb` + `configuration.rb`;
  the orphaned `configuration_spec.rb` was removed and its coverage folded
  into the central `spec/wild/configuration_spec.rb`.
- **MIN-Armstrong — `Wild::Analyzers::Permission::Error` subtree added**:
  `LoadError`, `AnalysisError`, `ExportError` under
  `Wild::Analyzers::Permission::Error < Wild::Analyzers::Error`. The old gem's
  `ConfigurationError` is subsumed by `Wild::ConfigurationError`.
- Export pair retained to preserve coverage during the move — the F6
  wire-or-delete audit lives at `wild-rvv.5.4`.
- Config-setter validation + freeze/frozen? machinery NOT carried over (Wild's
  no-freeze design); the 2 adversarial tests covering those features were
  deleted per F3 (no vanity tests of absent behavior). Rationale inline.
- **NOT in this PR** (deferred per Beck Tidy-First): the Fowler `detect_cycle`
  false-positive fix and the F3 vanity-test replacement — both are Role 6/7
  behavior changes under `wild-rvv.7`'s children (`wild-rvv.7.1`).

### Wild::Analyzers::TestFlakes

- Moved 21 source files from `wild-test-flake-forensics/lib/wild_test_flake_forensics/`
  into `lib/wild/analyzers/test_flakes/` under the 3-deep
  `Wild::Analyzers::TestFlakes::*` namespace (Role 5 PR-7). Sub-directories
  preserved: `models/`, `parsers/`, `detection/`, `analysis/`, `triage/`,
  `history/`, `export/`. Module Zeitwerk-rewritten from compact
  `module WildTestFlakeForensics` to nested form. New loader at
  `lib/wild/analyzers/test_flakes.rb`.
- 24 specs (unit + adversarial + integration) moved to
  `spec/wild/analyzers/test_flakes/`. Fixtures module (`TestFixtures`)
  rewrapped as `Wild::Analyzers::TestFlakes::TestSupport::Fixtures`; spec
  references to the old `TestFixtures::BASE_TIMESTAMP` constant rewritten to
  the new path; wired into spec_helper.
- **F1 — `Wild::Configuration::Analyzers::TestFlakes` extended** from 1 setting
  (`classifier_corpus_path` from PR-B) to 5: the 4 old-gem knobs (`minimum_runs`
  3, `flake_rate_threshold` 0.1, `max_history_entries` 10_000, `severity_weights`
  all-1.0 four-signal map) plus `classifier_corpus_path`. Defaults verbatim.
  Deleted the old gem's `version.rb` + `configuration.rb`; orphaned
  `configuration_spec.rb` removed (coverage folded into central config spec).
  `json_exporter.rb`'s metadata `version:` now reads `Wild::VERSION`.
- **MIN-Armstrong — `Wild::Analyzers::TestFlakes::Error` subtree added**:
  `ParseError`, `DetectionError`, `ExportError`. Old gem's `ConfigurationError`
  subsumed by `Wild::ConfigurationError`.
- 3 export files (`json`, `markdown`, `summary`) retained — F6 wire-or-delete
  audit (Beck named 2 of 3 as half-published) is `wild-rvv.5.4`.
- Config setter validation + freeze!/frozen? machinery NOT carried over; the
  freeze adversarial spec deleted per F3.
- **NOT in this PR** (deferred per Beck Tidy-First): the F3 golden-corpus
  classifier test (`wild-rvv.7.1`) and the `coverage_analyzer` dedup between
  Permission + TestFlakes (`wild-rvv.7.2`).

### Wild::Skillops

- Moved 20 source files from `wild-skillops-registry/lib/wild_skillops_registry/`
  into `lib/wild/skillops/` under the `Wild::Skillops::*` namespace (Role 5
  PR-5). Layout preserved verbatim: `models/`, `registry/`, `versioning/`,
  `governance/`, `discovery/`, `health/`, `export/` sub-directories.
  Module renamed from `WildSkillopsRegistry` to `Wild::Skillops` via
  Zeitwerk-nested rewrite (same pattern as PR #20 for Wild::Hooks). New
  loader at `lib/wild/skillops.rb` carries the `Wild::Skillops.build`
  factory + `RegistryFacade` class from the old gem entry point.
- 24 specs (unit + 2 adversarial + 2 integration) moved to
  `spec/wild/skillops/`. Fixtures module (`RegistryFixtures`) rewrapped as
  `Wild::Skillops::TestSupport::Fixtures` and wired into spec_helper.
- **F5 partial — `Wild::Configuration::Skillops` extended** from 1 setting
  (`:enabled`) to 6 (the 5 old-gem knobs: `max_skills` 1000, `max_versions_per_skill`
  50, `health_stale_threshold_hours` 24, `allowed_lifecycle_states`
  [:draft, :active, :deprecated, :retired], `allowed_health_states`
  [:available, :degraded, :unavailable, :unknown]). Defaults preserved
  verbatim.
- **F5 doc downgrade landed** (review wave, finding f-l07-1): `Registry::Store`'s
  class comment no longer claims "atomic read/write access." It now states the
  actual guarantee: single-process, non-concurrent, no atomicity/durability/
  thread-safety beyond plain Ruby `Hash` semantics, and names the unguarded
  check-then-set race in `#add` (f-l07-2) instead of implying it is safe.
  `tests/RTM.md` REQ-006 moves from Uncovered to Partial with a spec citation.
  The "Concurrent-style sequential updates" spec is renamed to "Rapid
  sequential updates (single caller, no threads)" (f-l07-4) since it never
  used a `Thread`. `Wild.config.skillops.enabled` remaining a no-op gate
  (f-l07-3) is a separate, still-open owner decision, not touched here.
  Advances bead "F5: Downgrade Wild::Skillops claims to match what the code
  can actually back up" (the `enabled` gate remains open).
- **F1 + MIN-Armstrong applied** — deleted the old gem's `version.rb` (one
  `Wild::VERSION` at gem level); collapsed the 7-class error tree into 6
  subclasses under `Wild::Skillops::Error` (`ValidationError`,
  `NotFoundError`, `DuplicateSkillError`, `LifecycleError`,
  `RegistryCapacityError`, `VersionCapacityError`). The old gem's
  `ConfigurationFrozenError` is subsumed by `Wild::ConfigurationError`
  (Wild engine no longer freezes config — by design). The Configuration
  setter validation + freeze/frozen? machinery is NOT carried over;
  the 6 adversarial tests covering those features were deleted per
  Beck/F3 (no vanity tests of absent behavior).
- Export pair (`json_exporter` + `markdown_exporter`) retained in this PR
  to preserve test coverage during the structure move — the F6 wire-or-
  delete audit lives at `wild-rvv.8.3` and stays open.
- Closes `wild-rvv.8` base move. Child `wild-rvv.8.1` (F5 doc downgrade) is
  now advanced by the `Registry::Store` comment fix above (the `enabled`
  gate itself remains open, see f-l07-3). `wild-rvv.8.2` (F10 BDUF cutback)
  and `wild-rvv.8.3` (F6 exporter audit) remain open as Role 6 + Role 7
  behavior follow-ups.

[Unreleased]: https://github.com/jeremylongshore/wild/compare/v0.0.0...HEAD
