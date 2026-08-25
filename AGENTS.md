# AGENTS.md — AI Agent Operations for wild

## Beads (bd) Issue Tracking

This project uses [beads](https://github.com/gastownhall/beads) for AI-friendly task tracking.
Tasks are stored in `.beads/` and tracked via the `bd` CLI.

## Quick Reference

```bash
bd ready                              # Find available work
bd show <id>                          # View issue details
bd update <id> --status in_progress   # Claim work
bd close <id> -r "Evidence"           # Complete work
bd note <id> "Progress update"        # Append a note
bd prime                              # LLM-optimized context
bd doctor                             # Health check
```

## Core Workflow

### Session Start
1. Run `/beads` or `bd prime` to recover context
2. Read [CLAUDE.md](CLAUDE.md) for canonical decisions (do NOT re-litigate)
3. Read `/home/jeremy/000-projects/wild/build-orchestration/README.md` if working on the 4-week consolidation build
4. Run `bd ready` to see available tasks
5. Pick a task and claim it: `bd update <id> --status in_progress`

### During Work
- Keep notes: `bd note <id> "what I did"`
- Create subtasks: `bd create "Subtask" --parent <id> -p 2`
- Check blockers: `bd blocked`

### Session End
1. Close finished tasks: `bd close <id> -r "Evidence of completion"`
2. Update in-progress tasks with status notes
3. Run quality gates (`rspec`, `rubocop`, `packwerk check` [boots `spec/dummy/`; informational], `brakeman -p spec/dummy`, `bundler-audit`)
4. **PUSH TO REMOTE**:
   ```bash
   git push
   git status  # MUST show "up to date with origin"
   ```
5. Hand off context for next session

## Priority Levels

| Priority | Label | Meaning |
|----------|-------|---------|
| P0 | Critical | Blocks everything, fix immediately |
| P1 | High | Important, address this session |
| P2 | Normal | Standard priority |
| P3 | Low | Nice-to-have, address when convenient |

## Critical Rules for AI Agents

- **Do NOT re-litigate canonical decisions in [CLAUDE.md](CLAUDE.md).** Topology, namespace extraction policy, configuration shape, error hierarchy, DI removal, vanity-test rejection, MCP bin-script form, stopwatch test — all locked by council rev2 and the user's plan.
- **The 13 council-blessed v1.1 fixes are tagged `label:thinker-council`.** Each closes with evidence referencing the rev2 verdict file path.
- **Per-namespace work goes through Packwerk.** Cross-namespace coupling needs an ADR amendment.
- **Tests are judgment tests, not vanity counts.** Beck/Karpathy/Lamport-mandated.
- **Every `rescue` in capability-gate decision paths emits a structured audit event.** F2 fix; non-negotiable.
- **MCP tool descriptions are versioned under `prompts/`.** Karpathy seam; changing a description requires a code-review-able diff.

## Creating Tasks

```bash
# Per-namespace fix
bd create "Fix F2 audit-blind error path in Wild::CapabilityGate" -t bug -p 0 \
  --label thinker-council,capability_gate \
  -d "Council rev2 §F2. Every rescue must emit structured failure event; :evaluation_error is hard-fail."

# Engine work
bd create "Wire Wild::Engine isolate_namespace + initializer order" -t feature -p 1 \
  --label engine \
  -d "DHH Week 2 plan. Rails-native shape."

# Adoption proof
bd create "Stopwatch test: bundle add wild → inspect_model_schema in <5 min" -t test -p 0 \
  --label adoption,stopwatch \
  -d "DHH Week 3 non-negotiable. v0.1.0 gate."
```

## Advanced Commands

```bash
bd list --status in_progress    # What am I working on?
bd list --label thinker-council # All 13 v1.1 fixes
bd statuses                     # List valid statuses
bd search "audit"               # Search by text
bd stale                        # Find stale issues
bd dep add <child> <parent>     # Add dependency
bd graph <id>                   # View dependency graph
```

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
