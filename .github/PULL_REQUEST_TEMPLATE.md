<!--
Full lane (any code / config / CI / schema / dependency / runtime change): fill every section.
Lightweight lane (docs or typo only): keep just "What", a one-line "Why", and "Refs".
Outsider test before requesting review: a stranger reading only this PR can answer what changed,
why, which component, how it was verified, how to roll back, what the risks are, what is unfinished.
-->

## What

<!-- 1-3 bullets. Name the affected Wild:: namespace(s) explicitly. -->

-

## Why + decision rationale

<!-- Why this change is necessary. One line "chose X over Y because Z" when a real alternative existed. -->

## Layer(s) touched

<!-- Packwerk package(s) / ADR-0003 tier(s). State any invariant change (a new inter-namespace edge needs an ADR-0003 amendment). -->

- [ ] `Wild::Introspection` (T4)
- [ ] `Wild::AdminTools` (T4)
- [ ] `Wild::CapabilityGate` (T3)
- [ ] `Wild::Telemetry::{Collector,Pipeline,Analysis}` (T1/T2)
- [ ] `Wild::Hooks` (T1)
- [ ] `Wild::Analyzers::{Permission,TestFlakes}` (T2)
- [ ] `Wild::Skillops` (T2)
- [ ] `Wild::Engine` / top-level
- [ ] Build / CI / docs only

## How it works

<!-- The shape of the change; the mechanism, not the diff. -->

## Verification & evidence

<!-- Link the proof: CI run URL, pasted rspec/rubocop tail, before/after repro output, verifier verdict. "Verified" without a link does not count. -->

- `bundle exec rspec` →
- `bundle exec rubocop` →
- CI run:
- If touching capability-gate decision paths: every `rescue` emits a structured audit event (F2) — evidence:
- If touching MCP tool descriptions: `prompts/<tool>.md` versioned with this change — evidence:

## Risk assessment

<!-- What could break; backward compatibility; user-facing vs internal; public API or contract change; rollback = revert this PR unless stated otherwise. -->

## Operational impact

<!-- Env vars, migrations, dependency changes, cost, secrets, deploy order. "None" is a valid answer. -->

## Follow-up & deferred

<!-- What this PR deliberately leaves out, each with its bead title. -->

## Governance links

<!-- Bead title(s) this PR advances or closes; ADR / plan / council-fix code (F#) if applicable. -->

## Refs / Closes

<!-- "Refs #N" while the cluster issue has other children; "Closes #N" only on the PR retiring its last child. -->

Refs #
