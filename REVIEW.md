# REVIEW.md

Reviewer law for `wild`, the standing instructions to the automated pull-request reviewer (MiniMax,
two advisory lanes) and to any human doing the same job.

`wild` is one mountable Rails engine gem holding ten `Wild::*` namespaces: safe runtime
introspection over MCP, privileged admin tools over MCP, a capability gate, a three-stage telemetry
system, hooks, two static-analysis namespaces, and skillops. Every namespace exists to let a Rails app hand an AI
agent real access without handing it the keys. The reviewer protects that boundary.

Report only defects the pull request introduces, verify each against the surrounding source, and
order findings by risk: security boundary, then fail-closed integrity, then correctness.

## Authority

Read `CLAUDE.md` and `AGENTS.md` first. `000-docs/adr/ADR-0001-topology.md` (one gem, ten
namespaces) and `ADR-0002` (a namespace earns its own gemspec only when all four of its criteria
hold: a production consumer outside the `jeremylongshore` namespace, concrete cadence divergence, an
API surface with no `# @api private` symbols left public, and a maintainer committing to the split)
are settled; a PR re-litigating either without an ADR amendment is a finding, not a refactor. Also locked: one `Wild::Configuration` with nested accessors, one
`Wild::Error` hierarchy, MCP servers as `bin/` scripts rather than gems, and no vanity tests.

## Top defect classes, in order

**1. A capability gate that fails open.** `Wild::CapabilityGate` is the whole safety story, and its
decision tree denies by default: unknown capability, ungranted caller, unmet prerequisite, then
allow. Hunt anything that turns a denial into an allowance or into an escaping exception.
`Evaluator#evaluate` must never raise except `AuditSchemaError`; its `rescue StandardError` path
must keep producing `reason: :evaluation_error` plus an audit event for a corrupted registry, a
hostile `caller_id` whose `#to_s` raises, or a checker bug. A new `raise` on that path, a reorder
that puts `rescue StandardError` before the `AuditSchemaError` rescue, or bare `String()` /
`#to_sym` inside `deny_evaluation_error` instead of the `SafeCoercion` helpers is a defect. A new
grant matcher or prerequisite checker that returns truthy on error, or treats a missing config value
as satisfied, is fail-open. `Gate#deny_with_error` is an audit-blind bug tripwire, not a policy
path: normal denials must not start flowing through it.

**2. Introspection that can mutate or leak.** `Adapter::WritePrevention` (`FORBIDDEN_METHODS`,
`WRITE_SQL_PATTERN`) is the mutation boundary: flag a new adapter path that reaches ActiveRecord
around it, or any weakening of the list or pattern. `Guard::QueryGuard` is the only entrance and
each tool must, in order, check `request_context.authenticated?`, resolve accessible columns, then
filter through `ResultFilter`. A tool that skips the auth check, returns early, or returns raw
`attributes` is a leak. `find_by_filter` must also reject a `field` outside the accessible set:
filtering on a blocked column leaks it by oracle even when the value never appears in the response.
`ColumnResolver.accessible_columns` returning `nil` means not allowed, so treating `nil` as empty or
permissive inverts the allowlist. `HARD_ROW_CEILING`, per-model `max_rows`, and `query_timeout_ms`
are denial-of-service controls; raising them or dropping the `Timeout.timeout` wrapper is a finding.
`IdentityResolver.find_api_key` must keep `SecurityUtils.secure_compare`: `==` on a credential is a
timing leak.

**3. Admin tools executing without their guards.** Preview issues a nonce, execute consumes it:
flag any executor path reachable without `validate_and_consume!`, and any nonce that is reusable,
not bound to (action, params, caller), or has its TTL removed. `BlastRadiusEnforcer` caps mutating
operations, so a new non-`read` operation routed through the read branch bypasses the cap, and a nil
`blast_radius_cap` reaching `within_cap?` compares against nil. `SlidingWindow` must keep every
touch of `@timestamps` inside its `Mutex` and must stay on the monotonic clock.

**4. PII or secrets escaping telemetry.** `Collector::Privacy::Filter` is a strict allowlist
(`ALLOWED_TOP_LEVEL_KEYS`, per-event-type `METADATA_ALLOWLISTS`, `FORBIDDEN_FIELD_NAMES`,
`ALLOWED_VALUE_TYPES`); a new event type with no allowlist entry must emit no metadata rather than
pass it through. Flag a `slice` turned into a `merge`, Hash or Array values admitted, or keys like
params, before_state, nonce, or backtrace added back. `Pipeline::Privacy::Redactor` must apply every
built-in pattern (email, API key, both AWS forms, GitHub token, bearer token, IP) before custom
ones; flag a removed pattern or an export path reading the unredacted transcript.
`Introspection::Audit::ParameterSanitizer` returns nil for an unknown tool name, and `AuditRecord`
keeps that nil verbatim (`attrs.fetch(:parameters, {})` does not substitute its default for a key
that is present and nil), so a new tool not added to its `case` writes a `parameters: nil` row: the
call is audited with its parameters silently dropped. That is an audit hole, not a leak, and it is
still a finding.

**5. Unvalidated MCP tool input.** `bin/wild-mcp-introspection` and `bin/wild-mcp-admin` take input
from an agent, meaning from an untrusted source. A model name, field name, or filter value arriving
over MCP must resolve against the configured allowlists (`model_config`, `column_names`) and must
never be interpolated into SQL, a shell command, `constantize`, `send`, or a `File` path. Both
scripts are stubs today; the first real implementation is the highest-value review in this repo.

## Invariants (name them by name in a finding)

- **Deny by default.** A missing grant, capability, model entry, or allowlist row is a denial.
- **The gate never raises.** `Evaluator#evaluate` returns an `EvaluationResult` on every path except
  a dev/test `AuditSchemaError`.
- **Every decision is audited.** A denial or allowance with no emitted event is a hole; an
  audit-write failure is logged, never doubly silent.
- **Introspection is read-only**, and nothing leaves it unfiltered by `ResultFilter`.
- **Allowlist, not denylist**, for models, columns, telemetry keys, and admin actions.
- **One config, one error tree, one `version.rb`.**
- **Namespace boundaries hold.** Cross-namespace access goes through the other namespace's public
  API and `package.yml` reflects it.
- **`# @api private` means private.** Widening an internal symbol is a versioning decision.

## What fail closed means here

Not "raises an exception". It means the unsafe direction is unreachable by accident:

1. On error or ambiguity the answer is deny, carrying a machine-readable reason.
2. The denial is audited before it is returned; a silent deny is barely better than a silent allow,
   because neither is observable.
3. The gate does not raise into consumer code. Raising is reserved for startup configuration errors
   (a broken `capabilities.yml` or `grants.yml` must blow up at boot) and dev/test schema violations.
4. A missing audit writer, a broken logger, or a disabled validator never upgrades a deny to allow.

A rescue with a permissive fallback, a `||` default that supplies an allowance, or an early
`return true` ahead of a guard violates this section even when every test passes.

## Generated, vendored, and machine-owned files

`.audit-harness/**` is vendored from `@intentsolutions/audit-harness` (changes go upstream) and
`.harness-hash` is its generated pin. `.beads/issues.jsonl` is a machine-written export with a custom
merge driver (`.gitattributes`), and `.beads/interactions.jsonl` is machine-written too. `Gemfile.lock`, `coverage/**`, `spec/dummy/{tmp,log}`, and the packwerk or rubocop
caches are artifacts. `.env.sops` is SOPS-encrypted and is meant to look like noise: never comment
on its contents, but do flag a plaintext `.env`, a secret committed anywhere else, or the forbidden
`sops -d | sed 's/^/export /'` pattern (it dumps every exported variable to stdout; the anchored
`sed -nE 's/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/export \1=\2/p'` form is correct). By contrast
`lib/wild/schemas/**` and `prompts/**` are hand-authored versioned data seams, so a change there is
a contract change and deserves more scrutiny than code, not less.

## What not to spend a comment on

RuboCop, Packwerk, Brakeman, bundler-audit, and Codecov findings (CI runs all of them, and the
Packwerk and Brakeman jobs are deliberately informational until `spec/dummy/` lands). Ruby style,
naming, frozen string literal comments, line length. Test count: "add more tests" is not a finding,
though "this guard has no test proving it denies" is. Features still pending: `build-orchestration/` is
referenced by CLAUDE.md and by both `bin/` stubs but is not tracked in this repository, so judge
pending work from the tree itself, above all the two MCP stubs that warn and exit 1 and the absent
`spec/dummy/`. And re-arguing
ADR-0001 or ADR-0002.

## Anti-ratchet

On a re-review after new pushes the bar does not rise: drop findings the update resolved, and raise
no new objections on unchanged lines you already accepted. Prefer a few high-conviction findings
over breadth. If the change is safe, correct, and inside the invariants, say `lgtm`. This reviewer
is advisory only and never blocks a merge.

## Sources

Every code-grounded claim above was read against the tree at the commit this branch points at,
short SHA `4e939a0`. Five claims were wrong when checked and have been corrected in place: the
"two CLI analyzers" description, the ADR-0002 paraphrase, the consequence of an unknown tool name
in `ParameterSanitizer`, the `.beads` merge-driver glob, and the pointer to
`build-orchestration/STATUS.md`. Line numbers are that commit's; re-verify after a move.

**Topology and locked decisions**

- One gem, ten namespaces: `000-docs/adr/ADR-0001-topology.md:1`, `:25`, `:28-41`
- Extraction criteria (all four): `000-docs/adr/ADR-0002-namespace-extraction-policy.md:21-52`
- One `Wild::Configuration`, one `Wild::Error`, no vanity tests, MCP servers as `bin/` scripts:
  `CLAUDE.md:14-20`; do-not-re-litigate list `AGENTS.md:56`
- Nested config accessors: `lib/wild/configuration.rb:45`, `:205`, `:312`, `:362-363`
- Error tree: `lib/wild/error.rb:13-26`, `:39-97`
- One `version.rb`: `lib/wild/version.rb`
- Per-namespace `package.yml`: `package.yml`, `lib/wild/introspection/package.yml` and its eight siblings
- `# @api private` in use: `lib/wild.rb:40`, `lib/wild/introspection.rb:70`, `lib/wild/skillops.rb:62`

**1. Capability gate**

- Decision tree order, deny by default: `lib/wild/capability_gate/evaluator.rb:44-48`, `:81-84`
- `evaluate` never raises except `AuditSchemaError`: `lib/wild/capability_gate/evaluator.rb:77-107`
- `AuditSchemaError` rescue ordered before `StandardError`: `lib/wild/capability_gate/evaluator.rb:88-96`
- `reason: :evaluation_error` plus audit event on the error path: `lib/wild/capability_gate/evaluator.rb:104-106`, `:111-124`
- `SafeCoercion` helpers rather than bare `String()` / `#to_sym`: `lib/wild/capability_gate/evaluator.rb:11-37`, `:118-123`
- Audit emitted on every evaluation; write failure logged, not doubly silent: `lib/wild/capability_gate/evaluator.rb:86`, `:178-196`, `:198-215`
- Grant matching and capability grant check: `lib/wild/capability_gate/grant.rb:30-36`
- Registry `known?` / `fetch`: `lib/wild/capability_gate/registry.rb:67`, `:73`
- Prerequisite checker fails closed on a missing or mismatched config value:
  `lib/wild/capability_gate/prerequisites/config_value_checker.rb:17-38`
- `Gate#deny_with_error` is an audit-blind tripwire, not a policy path:
  `lib/wild/capability_gate/gate.rb:40-44`, `:63-78`

**2. Introspection**

- `FORBIDDEN_METHODS`, `WRITE_SQL_PATTERN`: `lib/wild/introspection/adapter/write_prevention.rb:7`, `:22`, `:25`, `:41`
- Auth check, then column resolution, then `ResultFilter`, in all three entrances:
  `lib/wild/introspection/guard/query_guard.rb:19-35`, `:37-53`, `:55-73`
- `find_by_filter` rejects a field outside the accessible set: `lib/wild/introspection/guard/query_guard.rb:64`
- `QueryGuard` is the only entrance the tools use: `lib/wild/introspection/server/tools/inspect_model_schema.rb:35`,
  `lib/wild/introspection/server/tools/lookup_record_by_id.rb:39`,
  `lib/wild/introspection/server/tools/find_records_by_filter.rb:43`
- `accessible_columns` returns nil for a model with no config: `lib/wild/introspection/guard/column_resolver.rb:7-14`
- `ResultFilter` surface: `lib/wild/introspection/guard/result_filter.rb:7-15`
- `authenticated?`: `lib/wild/introspection/identity/request_context.rb:16-18`
- `HARD_ROW_CEILING`, `max_rows`, `query_timeout_ms` clamps:
  `lib/wild/introspection/configuration.rb:9-11`, `:81-82`, `:97-105`; `lib/wild/introspection/adapter/filtered_lookup.rb:7`, `:24-25`
- `Timeout.timeout` wrappers: `lib/wild/introspection/adapter/filtered_lookup.rb:38-42`,
  `lib/wild/introspection/adapter/record_lookup.rb:29-31`
- `model_config` and `blocked_columns_for`: `lib/wild/introspection/configuration.rb:44`, `:48`
- `secure_compare` on the API key: `lib/wild/introspection/identity/identity_resolver.rb:24-29`

**3. Admin tools**

- Preview issues a nonce, confirm consumes it: `lib/wild/admin_tools/guard/two_phase_flow.rb:13-32`
- `validate_and_consume!`, single use, TTL, binding to action plus params plus caller:
  `lib/wild/admin_tools/guard/nonce_manager.rb:17-18`, `:27-39`, `:41-59`, `:61-64`
- Read branch bypasses the cap; `within_cap?` compares against a possibly nil cap:
  `lib/wild/admin_tools/guard/blast_radius_enforcer.rb:9-19`, `:27-29`
- `SlidingWindow` mutex and monotonic clock: `lib/wild/admin_tools/guard/sliding_window.rb:12-13`, `:16-24`, `:26-46`, `:50-53`

**4. Telemetry privacy**

- `ALLOWED_TOP_LEVEL_KEYS`, `METADATA_ALLOWLISTS`, `FORBIDDEN_FIELD_NAMES`, `ALLOWED_VALUE_TYPES`:
  `lib/wild/telemetry/collector/privacy/filter.rb:8`, `:10-15`, `:17-23`, `:25`
- `slice` not `merge`; an event type with no allowlist entry emits no metadata; Hash and Array values dropped:
  `lib/wild/telemetry/collector/privacy/filter.rb:41`, `:49-52`, `:60`
- Built-in patterns (email, API key, both AWS forms, GitHub token, bearer token, IP) applied before custom ones:
  `lib/wild/telemetry/pipeline/privacy/redactor.rb:41-42`, `:47-59`, `:62-66`
- `ParameterSanitizer` returns nil for an unknown tool name: `lib/wild/introspection/audit/parameter_sanitizer.rb:9-18`
- That nil is passed straight through and stored verbatim: `lib/wild/introspection/audit/recorder.rb:29`,
  `lib/wild/introspection/audit/audit_record.rb:38`

**5. MCP input**

- Both servers are stubs that warn and exit 1: `bin/wild-mcp-introspection:11-12`, `bin/wild-mcp-admin:10-11`
- They are the gem's only executables: `wild.gemspec:43-44`
- Allowlists an implementation must resolve against: `lib/wild/introspection/configuration.rb:44`,
  `lib/wild/introspection/guard/column_resolver.rb:16-23`

**Generated, vendored, and machine-owned**

- Vendored harness and its pin: `.audit-harness/VERSION`, `.harness-hash`
- Beads merge driver: `.gitattributes:38`; exports `.beads/issues.jsonl`, `.beads/interactions.jsonl`
- Artifacts ignored: `.gitignore:12-13` (coverage), `:28` (packwerk cache), `:31` (rubocop cache),
  `:34-38` (dummy runtime dirs), `:53` (plaintext `.env`)
- `Gemfile.lock` deliberately tracked: `.gitignore:21-22`
- SOPS: `.env.sops`, `.sops.yaml`
- Hand-authored data seams: `lib/wild/schemas/`, `prompts/`

**CI, for the do-not-comment list**

- RuboCop: `.github/workflows/ci.yml:14-26`
- Packwerk informational: `.github/workflows/ci.yml:33-46`
- Brakeman informational until `spec/dummy/` lands, bundler-audit unconditional: `.github/workflows/ci.yml:49-71`
- RSpec on Ruby 3.2, 3.3, 3.4 plus Codecov: `.github/workflows/ci.yml:74-96`
- `spec/dummy/` is absent from the tree today: `spec/`
