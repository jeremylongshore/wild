# wild — Document Index

> The site-map for this repo's `000-docs/`. Read `CLAUDE.md` first for what the repo *is*;
> this answers "which document holds what". Filing follows the /doc-filing v4.4 scheme
> (`NNN-CC-ABCD-description.md`, flat, chronological). Architecture decisions live in
> `adr/` and are numbered separately.

*Last updated: 2026-08-25 (review-wave interlude opened: 009 plan filed; 010/011 reserved).*

## Numbered documents

| # | Doc | Type | Purpose |
|---|---|---|---|
| 000 | [000-AA-TMPL-after-action-report.md](000-AA-TMPL-after-action-report.md) | template | Canonical 9-section AAR skeleton (byte-identical copy of intent-os `000-AA-TMPL`; drift-checked by shasum) |
| 001 | [001-PP-BCASE-business-case.md](001-PP-BCASE-business-case.md) | plan | Why consolidate; what consolidation buys |
| 002 | [002-PP-PRD-product-requirements.md](002-PP-PRD-product-requirements.md) | plan | Requirements + the five-minute stopwatch test |
| 003 | [003-AT-ARCH-architecture.md](003-AT-ARCH-architecture.md) | architecture | Engine shape, namespace layout, boundary discipline, error hierarchy |
| 004 | [004-PP-UJRN-user-journey.md](004-PP-UJRN-user-journey.md) | plan | Rails developer adoption flow |
| 005 | [005-AT-SPEC-technical-spec.md](005-AT-SPEC-technical-spec.md) | spec | Stack, schemas, MCP transports |
| 006 | [006-OD-STAT-status.md](006-OD-STAT-status.md) | status | Build progress against the 11-role plan (mirror of the workspace `build-orchestration/STATUS.md`) |
| 007 | [007-AT-STND-codeql-strategy.md](007-AT-STND-codeql-strategy.md) | standard | CodeQL `security-extended` strategy (ruby + actions) |
| 008 | [008-AT-AUDT-pre-move-coupling-survey.md](008-AT-AUDT-pre-move-coupling-survey.md) | audit | Static cross-namespace coupling survey of the 10 old gems against ADR-0003 |
| 009 | [009-PP-PLAN-strategic-review-and-fix-wave-2026-08-25.md](009-PP-PLAN-strategic-review-and-fix-wave-2026-08-25.md) | plan | Plan of record for the review-wave interlude between Role 6 and Role 7 |
| 010 | `010-RA-REVW-review-wave-findings-and-bead-docket-<date>.md` + `010a-…-data.json` | review | (reserved) Review record + machine-readable findings and bead dispositions |
| 011 | `011-AA-AACR-strategic-review-and-fix-wave-<date>.md` | AAR | (reserved) After-action report for the review wave |

## Architecture decision records (`adr/`)

| ADR | Decision |
|---|---|
| [ADR-0001](adr/ADR-0001-topology.md) | One gem, ten namespaces (Topology A), council-blessed |
| [ADR-0002](adr/ADR-0002-namespace-extraction-policy.md) | When a namespace earns its own gemspec |
| [ADR-0003](adr/ADR-0003-namespace-dependency-graph.md) | Four-tier namespace dependency DAG enforced by Packwerk `package.yml` |

## Where other state lives

| State | Location |
|---|---|
| Task tracking | `.beads/` (prefix `wild`; consolidation epic + the review-wave epic are both top-level) |
| Live build status (canonical) | workspace `../build-orchestration/STATUS.md` (untracked); 006 mirrors it |
| Council verdict (immutable) | `wild-rails-ai-ops/000-docs/013-AT-AUDT-thinker-council-verdict-rev2-2026-05-29.md` |
| Changelog | `../CHANGELOG.md` (per-namespace subsections under `[Unreleased]`) |
