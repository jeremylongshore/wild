# Contributing to wild

Thank you for your interest in contributing to **wild**! This guide will help you get started.

## Getting Started

### Prerequisites

- Git
- GitHub account
- Ruby 3.2, 3.3, or 3.4
- Bundler 2.4+
- A Rails 7.1+ application to test the engine against (for integration work)

### Development Setup

```bash
# Clone the repository
git clone https://github.com/jeremylongshore/wild.git
cd wild

# Install dependencies
bin/setup

# Wire local git hooks (one-time per clone — pre-commit RuboCop, commit-msg
# conventional-commits, pre-push RSpec smoke)
scripts/install-hooks

# Run the test suite
bundle exec rspec

# Run lint
bundle exec rubocop

# Run namespace-boundary lint (informational until P2)
bundle exec packwerk check

# Run security gates
bundle exec brakeman
bundle exec bundler-audit check --update
```

### Local git hooks

`scripts/install-hooks` symlinks three plain-shell hooks into `.git/hooks/`:

| Hook | What it does | Bypass |
|---|---|---|
| `pre-commit` | RuboCop on staged Ruby files (`*.rb`, `*.rake`, `*.gemspec`, `Rakefile`, `Gemfile`) | `git commit --no-verify` |
| `commit-msg` | Enforces Conventional Commits format (`type(scope)?: subject`) | `git commit --no-verify` |
| `pre-push` | RSpec smoke against `spec/wild_spec.rb` (fast; full suite runs in CI) | `git push --no-verify` |

To uninstall: `scripts/install-hooks --uninstall`.

The hooks are committed under `scripts/git-hooks/` so updates flow through PRs.
This pattern is intentionally lightweight — no gem dependency on lefthook / pre-commit /
husky. The audit harness vendored at `.audit-harness/` provides the deeper gates
(escape-scan, hash-pinning, CRAP scoring, bias detection) and is invoked via
`scripts/audit-harness <command>`.

## Repository shape

This is **one Rails engine gem** with ten namespaces under `lib/wild/`. See
[`000-docs/adr/ADR-0001-topology.md`](000-docs/adr/ADR-0001-topology.md) for the
canonical decision. The namespace structure is enforced by Packwerk; adding a
new top-level namespace requires an ADR amendment.

| Namespace | Directory |
|---|---|
| `Wild::Introspection` | `lib/wild/introspection/` |
| `Wild::AdminTools` | `lib/wild/admin_tools/` |
| `Wild::CapabilityGate` | `lib/wild/capability_gate/` |
| `Wild::Telemetry::Collector` | `lib/wild/telemetry/collector/` |
| `Wild::Telemetry::Pipeline` | `lib/wild/telemetry/pipeline/` |
| `Wild::Telemetry::Analysis` | `lib/wild/telemetry/analysis/` |
| `Wild::Hooks` | `lib/wild/hooks/` |
| `Wild::Analyzers::Permission` | `lib/wild/analyzers/permission/` |
| `Wild::Analyzers::TestFlakes` | `lib/wild/analyzers/test_flakes/` |
| `Wild::Skillops` | `lib/wild/skillops/` |

## How to Contribute

### Reporting Bugs

1. Search [existing issues](https://github.com/jeremylongshore/wild/issues) first
2. Open a [bug report](https://github.com/jeremylongshore/wild/issues/new?template=bug_report.md)
3. Include reproduction steps, expected vs actual behavior, Ruby + Rails version, and a minimal Gemfile

### Suggesting Enhancements

1. Check [existing feature requests](https://github.com/jeremylongshore/wild/issues?q=label%3Aenhancement)
2. Open a [feature request](https://github.com/jeremylongshore/wild/issues/new?template=feature_request.md)
3. For cross-namespace work, name the affected namespaces explicitly

### Pull Requests

1. Fork the repository
2. Create a feature branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Make your changes
4. Add or update tests
5. Ensure `rspec`, `rubocop`, `packwerk check`, `brakeman`, and `bundler-audit` all pass
6. Commit with [conventional commit messages](#commit-messages)
7. Push and open a pull request

## Development Process

### Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Release-ready code |
| `feature/*` | New features |
| `fix/*` | Bug fixes |
| `docs/*` | Documentation changes |

### Testing

Per-namespace test tasks:

```bash
bundle exec rake test:introspection
bundle exec rake test:admin_tools
bundle exec rake test:capability_gate
bundle exec rake test:telemetry
bundle exec rake test:hooks
bundle exec rake test:analyzers
bundle exec rake test:skillops
```

Full suite:

```bash
bundle exec rspec
```

Coverage threshold is enforced via SimpleCov in `spec/spec_helper.rb` and reported
to Codecov from CI.

### Namespace-boundary discipline

Packwerk enforces that namespaces only depend on what their `package.yml` declares.
If you find yourself wanting to add a cross-namespace import, prefer:

1. Refactor the shared concept into `lib/wild/hooks/` (the shared-concerns landing zone), OR
2. Declare an explicit public API on the source namespace and depend on that

A new private API symbol gets `# @api private` discipline; treating it as public requires an ADR.

### Code Review

- All PRs require maintainer approval
- CI must pass (RSpec on Ruby 3.2/3.3/3.4 + RuboCop + Packwerk + brakeman + bundler-audit + Codecov)
- Keep PRs focused — one namespace per PR when possible

## Style Guides

### Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/) with namespace-aware scopes:

```
<type>(<scope>): <subject>

[optional body]
[optional footer]
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`

**Scopes** prefer the namespace name, lowercase: `introspection`, `admin_tools`, `capability_gate`, `telemetry`, `hooks`, `permission`, `test_flakes`, `skillops`, `engine`, `gemspec`, `ci`.

**Examples:**
- `feat(introspection): add list_allowed_models discovery tool`
- `fix(capability_gate): emit audit event on :evaluation_error path`
- `refactor(telemetry): inline TelemetryRecord superclass`

### Code Style

- RuboCop is the formatter — `bundle exec rubocop -a` before committing
- Two-space indent for Ruby
- Prefer `frozen_string_literal: true` at the top of every Ruby file
- Use `# @api private` on internal symbols not intended for consumers

## Community

- **Questions**: [GitHub Discussions](https://github.com/jeremylongshore/wild/discussions)
- **Bugs**: [Issue Tracker](https://github.com/jeremylongshore/wild/issues)
- **Email**: jeremy@jeremylongshore.com

## License

By contributing, you agree that your contributions will be licensed under the
project's [MIT License](LICENSE).

---

*Thank you for helping improve wild!*
