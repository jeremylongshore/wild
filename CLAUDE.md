# CLAUDE.md

## Project Overview

**wild** — Rails engine + generator: ten `Wild::*` namespaces consolidated into one mountable gem.

- **Language**: Ruby (Rails 7.1+ engine gem)
- **Repo**: https://github.com/jeremylongshore/wild
- **License**: MIT
- **Status**: v0.1.0 in flight per 4-week consolidation build plan

## Canonical decisions (do NOT re-litigate)

1. **One gem, ten namespaces (Topology A).** Locked by 7-seat thinker council rev2 (4 explicit, 0 dissenting on topology). ADR-0001 is the source of truth. If a future session believes a namespace should split, the procedure is ADR-0002, not freelance refactor.
2. **Namespace extraction policy.** A namespace earns its own gemspec only when a second external consumer with divergent cadence appears. Optionality without paying coordination tax up front.
3. **One `Wild::Configuration`** with nested accessors. No per-namespace `Configuration` classes. (Replaces nine old broken `Configuration` singletons.)
4. **One `Wild::Error` base hierarchy.** Armstrong-mandated, council-blessed. ~30 LOC for consumer-distinguishable error tree.
5. **DI container around ActiveJob / Rails.cache / Flipper is dead.** Adapters are defaulted in `lib/wild/admin_tools/`. The injection points remain as overrides but no longer require the consumer to wire them.
6. **No vanity tests.** Test count is not a metric. Beck-mandated, council-blessed.
7. **MCP servers ship as `bin/` scripts**, not separate gems. `bin/wild-mcp-introspection` and `bin/wild-mcp-admin`. Plugin packaging is downstream in `plugins/wild/`.
8. **Five-minute stopwatch test is the v0.1.0 gate.** From a fresh `rails new` to a successful MCP `inspect_model_schema` call in under five minutes. If it fails, v0.1.0 doesn't ship.

## Critical reference docs

- `/home/jeremy/000-projects/wild/wild-rails-ai-ops/000-docs/013-AT-AUDT-thinker-council-verdict-rev2-2026-05-29.md` — final council verdict, source of truth for every fix
- `/home/jeremy/000-projects/wild/wild-rails-ai-ops/000-docs/010-AT-VRDT-dhh-2026-05-29.md` — week-by-week migration plan
- `/home/jeremy/000-projects/wild/wild-rails-ai-ops/000-docs/011-AT-AUDT-thinker-council-verdict-2026-05-29.md` (rev1) — P0/P1 findings table
- `/home/jeremy/000-projects/wild/wild-rails-ai-ops/000-docs/012-AT-RBTL-jeremy-defense-of-multi-repo-2026-05-29.md` — defense + 6 earned concessions
- `/home/jeremy/000-projects/wild/build-orchestration/` — 11-role build plan scaffolding (P0 → P4) with per-role briefing packets and gate definitions

## Task Tracking with Beads (bd)

**Beads provides post-compaction recovery.** Run `/beads` at session start.

**Workflow:** `bd update <id> --status in_progress` → work → `bd close <id> --reason "evidence"`

Key commands: `bd prime` (LLM context), `bd ready`, `bd list --status in_progress`, `bd doctor`

The 13 council-blessed v1.1 fixes are tagged `label:thinker-council` and grouped under per-namespace epic beads. Closing the last child of an epic closes the epic.

## Build & Test

```bash
bundle install
bundle exec rspec                          # full suite
bundle exec rake test:<namespace>          # one namespace
bundle exec rubocop                        # style
bundle exec packwerk check                 # namespace boundary
bundle exec brakeman                       # security
bundle exec bundler-audit check --update   # dependencies
```

## Project Structure

```
wild/
├── 000-docs/                # Enterprise documentation (doc-filing v4) + ADRs
│   └── adr/                 # ADR-0001 topology, ADR-0002 namespace extraction
├── .github/                 # CI/CD, issue templates, PR template, dependabot, FUNDING, CODEOWNERS
├── bin/                     # bin/setup, bin/console, bin/wild-mcp-introspection, bin/wild-mcp-admin
├── lib/
│   ├── wild.rb              # top-level autoload + Wild.configure entry point
│   └── wild/
│       ├── engine.rb        # Wild::Engine (Rails engine)
│       ├── version.rb       # one and only version.rb
│       ├── error.rb         # Wild::Error hierarchy
│       ├── configuration.rb # one Wild::Configuration with nested accessors
│       ├── introspection/
│       ├── admin_tools/
│       ├── capability_gate/
│       ├── telemetry/
│       │   ├── collector/
│       │   ├── pipeline/
│       │   └── analysis/
│       ├── hooks/
│       ├── analyzers/
│       │   ├── permission/
│       │   └── test_flakes/
│       └── skillops/
├── prompts/                 # versioned MCP tool descriptions (Karpathy seam)
├── schemas/                 # response-shape schemas-as-data (Hickey seam)
├── spec/                    # one consolidated test tree, namespaced by module
├── lib/generators/wild/     # rails g wild:install
├── packwerk.yml             # namespace boundary lint
├── codecov.yml              # coverage thresholds
├── .rubocop.yml             # style + architectural lint
├── wild.gemspec             # one gemspec
├── Gemfile                  # one Gemfile
├── Rakefile                 # task aggregator including rake test:<namespace>
├── CLAUDE.md                # this file
├── CONTRIBUTING.md          # contribution guidelines
├── SECURITY.md              # security policy
└── README.md                # project overview
```

## Conventions

- Commit messages: `<type>(<namespace-or-scope>): <subject>` — see CONTRIBUTING.md
- Branch naming: `feature/<name>`, `fix/<name>`, `docs/<name>`
- PR workflow: feature branch → PR → review → merge
- Doc filing: `000-docs/` with v4 naming convention
- Per-namespace SemVer stamps inside the single gem's version.rb history (Beck Refinement #3)
- `# @api private` discipline on internal symbols not intended for consumers

## Secrets

This repo follows the Intent Solutions SOPS + age standard. Encrypted secrets
live in `.env.sops` and travel with the code. Decryption uses age (the engineer's
private key at `~/.config/sops/age/keys.txt`; CI uses `SOPS_AGE_KEY` GH Actions
secret). The wild gem itself ships no application secrets — the scaffolding is in
place for when consumer-facing examples (sample Rails app with `wild` mounted)
need them.

| File | Role |
|---|---|
| `.sops.yaml` | Recipient list + encryption rules |
| `.env.sops` | Encrypted secrets (committed); decrypts to env via `scripts/sops-env` |
| `secrets.example.yaml` | Template of expected keys (no values) |
| `scripts/sops-env` | Wrapper: decrypts to `/dev/shm` tmpfs, sources into env, wipes |

Never commit a plaintext `.env`. The `eval ... | sed` pattern documented in
the global CLAUDE.md (anchored regex only) is the correct way to source. The
`sops -d | sed 's/^/export /'` pattern is forbidden (leaks all envvars to stdout
if any blank/comment line slips through).

## Out of scope here

- Per-namespace implementation details — those live in each `lib/wild/<namespace>/` directory's own notes
- The 10 old `wild-*` repos — they get archive-and-redirect treatment in Phase 4 of the build plan, not by this CLAUDE.md
- The `wild-rails-ai-ops` umbrella repo — only Role 11 (deployment-engineer) touches it, and only in P4


<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:7510c1e2 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
