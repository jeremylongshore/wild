# Technical Spec: wild

> Stack, schemas, MCP transports, CI shape.

**Author:** Jeremy Longshore
**Date:** 2026-05-28
**Status:** Draft

## Stack

| Layer | Tech |
|---|---|
| Language | Ruby 3.2, 3.3, 3.4 (matrix tested) |
| Framework | Rails 7.1+ (engine gem) |
| Tests | RSpec 3.13+, SimpleCov, dummy Rails app under `spec/dummy/` |
| Style | RuboCop (standard + Rails cops) |
| Boundaries | Packwerk |
| Security | brakeman, bundler-audit |
| Coverage | Codecov (CODECOV_TOKEN secret) |
| CI | GitHub Actions |
| Dependency mgmt | Dependabot (weekly Monday) |
| Tracking | Beads (`bd`) — `.beads/` in repo |
| Generator | Standard Rails generator under `lib/generators/wild/install/install_generator.rb` |

## Gemfile dependencies (proposed for v0.1.0)

```ruby
# Runtime
spec.add_dependency "rails", ">= 7.1"

# Development
spec.add_development_dependency "rspec", "~> 3.13"
spec.add_development_dependency "rspec-rails", "~> 6.1"
spec.add_development_dependency "simplecov", "~> 0.22"
spec.add_development_dependency "simplecov-cobertura", "~> 2.1"  # Codecov XML
spec.add_development_dependency "rubocop", "~> 1.65"
spec.add_development_dependency "rubocop-rails", "~> 2.25"
spec.add_development_dependency "rubocop-rspec", "~> 3.0"
spec.add_development_dependency "packwerk", "~> 3.2"
spec.add_development_dependency "brakeman", "~> 6.2"
spec.add_development_dependency "bundler-audit", "~> 0.9"
spec.add_development_dependency "sqlite3", "~> 2.0"  # dummy app
```

## CI matrix

| Job | Runner | Steps |
|---|---|---|
| lint | ubuntu-latest, Ruby 3.3 | `bundle exec rubocop --no-server --parallel --display-cop-names` |
| boundary | ubuntu-latest, Ruby 3.3 | `bundle exec packwerk check` |
| security | ubuntu-latest, Ruby 3.3 | `brakeman` + `bundler-audit --update && bundler-audit check` |
| test (matrix) | ubuntu-latest, Ruby 3.2/3.3/3.4 | `COVERAGE=1 bundle exec rspec --format documentation`; upload to Codecov on Ruby 3.3 |

CI is one workflow. The 10 old gems had 10 workflows; consolidation dissolves that overhead.

## Coverage policy

| Scope | Threshold |
|---|---|
| Per-file | 75% |
| Per-namespace | 80% |
| Repo-wide | 85% |

Enforced through SimpleCov in `spec/spec_helper.rb` AND Codecov status checks. Regressions fail the PR.

## MCP transport

Two MCP servers are independent `bin/` scripts:

### `bin/wild-mcp-introspection`

- Reads `--access-policy <path>` (defaults to `./config/wild/access_policy.yml` if running in a Rails root)
- Reads `--allowed-models <comma-list>` (overrides policy)
- Speaks MCP over stdio (`stdin/stdout`)
- Loads tool descriptions from `prompts/introspection/*.md`
- Loads response schemas from `schemas/introspection/*.yml`

Tools exposed:

| Tool | Description file | Response schema |
|---|---|---|
| `inspect_model_schema` | `prompts/introspection/inspect_model_schema.md` | `schemas/introspection/model_schema.yml` |
| `list_allowed_models` | `prompts/introspection/list_allowed_models.md` | `schemas/introspection/model_list.yml` |
| `inspect_routes` | `prompts/introspection/inspect_routes.md` | `schemas/introspection/route_list.yml` |

### `bin/wild-mcp-admin`

- All tools pass through `Wild::CapabilityGate`
- Tool descriptions under `prompts/admin_tools/*.md`
- Response schemas under `schemas/admin_tools/*.yml`
- Audit event emitted on every gate decision (F2)

Tool surface to be finalized in P2 by Role 9 (`ai-engineer`). Initial set inherits from `wild-admin-tools-mcp` v1 after dead/half-published surface (F6) is pruned.

## Audit event schema (F2)

`schemas/capability_gate/audit_event.yml`:

```yaml
type: object
required:
  - timestamp
  - decision_id
  - capability
  - subject
  - outcome
  - policy_version
  - rationale
  - audit_emit_ms
properties:
  timestamp:        { type: string, format: date-time }
  decision_id:      { type: string, format: uuid }
  capability:       { type: string }
  subject:          { type: string }
  outcome:          { type: string, enum: [allow, deny, evaluation_error] }
  policy_version:   { type: string }
  rationale:        { type: string }
  audit_emit_ms:    { type: number, minimum: 0 }
```

## Versioning

`lib/wild/version.rb` is the one and only version constant:

```ruby
module Wild
  VERSION = "0.1.0"
end
```

Per-namespace SemVer stamps live in CHANGELOG.md sections (Beck Refinement #3) — they document compatibility commitments per namespace without splitting the gemspec.

## Beads layout

One root `.beads/` per ADR-0001 — but with ten namespace epics, one per `Wild::*` namespace, so per-namespace progress is queryable via `bd list --label <namespace>`.

## Distribution

- GitHub Releases (gem attached)
- RubyGems.org (`gem push wild-X.Y.Z.gem`) — manual step in release workflow once user provides a RubyGems API key

## Out of scope

- Multi-tenant / horizontal scale-out (single-process gem; one Puma worker is the scope)
- Built-in WebSocket / push transport (MCP stdio + HTTP only)
- Storage backends other than `Rails.cache` and `Rails.logger`
- Per-namespace separate gemspecs (deferred to ADR-0002 trigger)
