# REVIEW.md

Reviewer law for `wild`, the standing instructions to the automated pull-request reviewer (MiniMax,
two advisory lanes) and to any human doing the same job.

`wild` is one mountable Rails engine gem holding ten `Wild::*` namespaces: safe runtime
introspection over MCP, privileged admin tools over MCP, a capability gate, a three-stage telemetry
system, hooks, two CLI analyzers, and skillops. Every namespace exists to let a Rails app hand an AI
agent real access without handing it the keys. The reviewer protects that boundary.

Report only defects the pull request introduces, verify each against the surrounding source, and
order findings by risk: security boundary, then fail-closed integrity, then correctness.

## Authority

Read `CLAUDE.md` and `AGENTS.md` first. `000-docs/adr/ADR-0001-topology.md` (one gem, ten
namespaces) and `ADR-0002` (a namespace earns its own gemspec only when a second external consumer
with divergent cadence appears) are settled; a PR re-litigating either without an ADR amendment is a
finding, not a refactor. Also locked: one `Wild::Configuration` with nested accessors, one
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
`Introspection::Audit::ParameterSanitizer` returns nil for an unknown tool name, so a new tool not
added to its `case` writes unsanitized parameters into the audit log.

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
`.harness-hash` is its generated pin. `.beads/*.jsonl` is a machine-written export with a custom
merge driver. `Gemfile.lock`, `coverage/**`, `spec/dummy/{tmp,log}`, and the packwerk or rubocop
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
though "this guard has no test proving it denies" is. Features still pending in
`build-orchestration/STATUS.md`, including the two MCP stubs that warn and exit 1. And re-arguing
ADR-0001 or ADR-0002.

## Anti-ratchet

On a re-review after new pushes the bar does not rise: drop findings the update resolved, and raise
no new objections on unchanged lines you already accepted. Prefer a few high-conviction findings
over breadth. If the change is safe, correct, and inside the invariants, say `lgtm`. This reviewer
is advisory only and never blocks a merge.
