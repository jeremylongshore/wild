## Summary

<!-- 1-3 bullets. Name the affected Wild:: namespace(s) explicitly. -->

-
-
-

## Type of Change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Documentation (updates to docs, comments, or README)
- [ ] Refactor (code change that neither fixes a bug nor adds a feature)
- [ ] CI/CD (changes to build process, workflows, or tooling)
- [ ] Council fix (closes a `label:thinker-council` bead — reference the bead and the fix code F#)

## Namespace(s) touched

- [ ] `Wild::Introspection`
- [ ] `Wild::AdminTools`
- [ ] `Wild::CapabilityGate`
- [ ] `Wild::Telemetry::{Collector,Pipeline,Analysis}`
- [ ] `Wild::Hooks`
- [ ] `Wild::Analyzers::{Permission,TestFlakes}`
- [ ] `Wild::Skillops`
- [ ] `Wild::Engine` / top-level
- [ ] Build / CI / docs only

## Checklist

- [ ] `bundle exec rspec` passes
- [ ] `bundle exec rubocop` passes
- [ ] `bundle exec packwerk check` passes
- [ ] `bundle exec brakeman` passes
- [ ] `bundle exec bundler-audit check --update` passes
- [ ] Codecov delta non-negative (no coverage regression)
- [ ] CHANGELOG updated under the affected namespace's subsection
- [ ] No secrets or credentials committed
- [ ] Commits follow conventional commit format with namespace scope
- [ ] If touching capability-gate decision paths: confirm every `rescue` emits a structured audit event (F2)
- [ ] If touching MCP tool descriptions: confirm `prompts/<tool>.md` is versioned with this change
- [ ] Self-reviewed the diff before requesting review

## Testing

<!-- Describe the tests you ran and how to reproduce them -->

## Related Issues / Beads

<!-- Use "Closes #123" to auto-close GH issues on merge. Reference beads by title. -->

Closes #
