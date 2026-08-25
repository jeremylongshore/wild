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

# Run namespace-boundary lint (boots spec/dummy/; enforced)
bundle exec packwerk check

# Run security gates (brakeman scans spec/dummy/, the dummy Rails app
# Wild::Engine mounts into)
bundle exec brakeman -p spec/dummy
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

The wild gem ships ten `Wild::*` namespaces in one Rails engine. Cross-namespace
coupling is governed by three rules, layered:

| Layer | Mechanism | What it catches |
|---|---|---|
| 1 | Packwerk (`packwerk.yml` + per-namespace `package.yml`) | Cross-namespace imports not declared in `dependencies:` |
| 2 | RuboCop (`.rubocop.yml`) | Forbidden constants, style conventions |
| 3 | `# @api private` YARD discipline (this section) | Internal symbols not meant for cross-namespace use |

The allowed-edge graph between namespaces is locked by
[`000-docs/adr/ADR-0003-namespace-dependency-graph.md`](000-docs/adr/ADR-0003-namespace-dependency-graph.md).
A four-tier DAG: Hooks → Telemetry / Analyzers / Skillops → CapabilityGate →
Introspection + AdminTools. The ADR enumerates every edge row-by-row.

#### The `# @api private` discipline

Every namespace's `lib/wild/<namespace>/` directory has an implicit two-tier shape:

| Tier | Marker | Visible to |
|---|---|---|
| **Public** | None | Other namespaces (per ADR-0003), engine, consumers |
| **Private** | `# @api private` YARD tag on the class, module, or method | Only that namespace's own files |

Mark internal symbols with `# @api private` directly above the declaration:

```ruby
module Wild
  module CapabilityGate
    # @api private
    class RuleCompiler
      # ...
    end

    class Gate
      # @api private
      def normalize_subject(raw)
        # ...
      end
    end
  end
end
```

A consumer calling a `# @api private` symbol gets no Ruby runtime error, but
**Packwerk's `enforce_privacy: true`** (set in every namespace's `package.yml`,
per ADR-0003) flags cross-namespace reads of these symbols at
`bundle exec packwerk check` time. The YARD tag is the contract; Packwerk is
the gate. Within-namespace use is unrestricted; cross-namespace use fails
CI's boundary job. Breakage between releases for `# @api private` symbols is
expected — they exist outside the public contract by design.

#### When you want to add a public API symbol

A symbol becomes public by NOT carrying `# @api private`. Adding one requires:

1. **CHANGELOG entry** under that namespace's section. Describe the symbol's
   signature + intended consumer use case.
2. **An RSpec** covering the public contract (input → output, error cases).
3. **PR review by the namespace's CODEOWNERS** (currently `@jeremylongshore`;
   per-namespace ownership lands when contributors join).

This applies whether the symbol is brand new OR you're removing `# @api private`
from an existing internal class. Either path opens the same contract.

#### When you want to add a new inter-namespace dependency

If you find yourself reaching from namespace A into namespace B and Packwerk
flags it, **stop and inspect ADR-0003**:

1. **Is the edge already in the graph?** If yes, add `B` to A's
   `lib/wild/<a>/package.yml` `dependencies:` list. Done.
2. **Is the edge NOT in the graph?** That's the design constraint working.
   Three legitimate paths:
   - **Refactor the shared concept into `Wild::Hooks`** (the Tier 1 shared-concerns
     substrate). Both A and B can then depend on Hooks. *This is the default
     answer for shared utilities.*
   - **Declare an explicit public API on B** and depend on that via the existing
     graph. Often the right answer when only a small surface of B needs to be
     visible.
   - **Amend ADR-0003** if you genuinely need a new edge. ADR amendments require
     a PR with rationale + ADR text update + Packwerk config update + CODEOWNERS
     approval. The friction is intentional — boundary changes are decisions,
     not drift.

Do NOT just add the edge to `package.yml` and ship. Packwerk would let it
through (since you'd have updated the config), but the contract recorded in
the ADR would silently disagree with the running code. The next reviewer to
hit a related question pays the price.

#### When you want to add a new top-level namespace

This requires an **ADR amendment to ADR-0001** (the topology decision). The
council rev2 verdict locked the namespace count at ten. Adding an eleventh
is allowed but requires explicit re-engagement with the decision substrate.

#### When Packwerk flags an import

`bundle exec packwerk check` runs in CI as a required, blocking check (the
`boundary` job): every `lib/wild/<namespace>/package.yml` declares its
dependency on the root package ('.') for the substrate every tier may use
(`Wild::Error` subclasses, `Wild.config`, `Wild::Configuration`,
`Wild::Engine`), and the ten `lib/wild/<namespace>.rb` entry files are
excluded in `packwerk.yml` (same treatment as the five engine-substrate
files) because they are each namespace's own wiring code, not a genuine
root-to-namespace coupling. **Treat local Packwerk output as binding** — the intentional friction
this discipline relies on erodes during the soak window if contributors wait
for CI to enforce it. Run locally before pushing:

```bash
bundle exec packwerk check
```

A violation usually means one of:

| Symptom | Fix |
|---|---|
| Importing a constant from a namespace not in your `package.yml` `dependencies:` | Pick one of the three paths above; do NOT just append to `dependencies:` without checking ADR-0003 |
| Importing a `# @api private` symbol from another namespace | Refactor — that symbol is internal by contract |
| Cyclic dependency detected | ADR-0003 forbids cycles. Refactor the shared concept into Hooks (Tier 1) |
| Reading a YAML / data file from another namespace | Move the file to `lib/wild/schemas/` (the shared schemas-as-data substrate, per ADR-0003 § Cross-namespace data). NOT a Packwerk package; loadable by any namespace |

#### `lib/wild/schemas/` is shared data, not code

The schemas directory holds YAML files shared across namespaces (e.g.,
`wildcard_corpus.yml` consumed by both `Wild::Analyzers::Permission` and
`Wild::CapabilityGate`). Per ADR-0003 it is intentionally **not a Packwerk
package** — any namespace may load any schema file. Adding a new shared
schema follows the same dual-CHANGELOG discipline as adding a wildcard
form: entry under every namespace that loads it, plus a spec verifying
the file's structure.

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
