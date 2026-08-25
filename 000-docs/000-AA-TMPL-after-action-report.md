# 000-AA-TMPL — After-action report template (canonical)

> **What this is and why it matters.** The copy-pasteable skeleton for the mandatory
> after-action report (AAR) every epic and major milestone must file. The /doc-filing v4.4
> standard names this file (`000-AA-TMPL-after-action-report.md`) in its canonical tree but
> ships no content; the 9-section format below is Jeremy Longshore's doctrine (2026-07-10),
> codified in `039-DR-STND-epic-documentation-aar-and-reporting-standard.md` — read that for
> the rules (when an AAR is due, what "n/a" requires, where it's filed and published).
> **This file is the canonical source**; copies in other repos are shasum-drift-checked
> against it. To use: copy everything below the cut line into
> `NNN-AA-AACR-<epic-slug>.md` at the next free number and fill every section — none are
> optional.

---
<!-- ── cut here — copy everything below into NNN-AA-AACR-<epic-slug>.md ────────── -->

# NNN-AA-AACR — <epic name> after-action report

> <Plain-English opening: what this epic was and why it mattered, for a reader who has
> never seen this estate. Expand shorthand on first use.>

- **Epic:** <bead ID + plain-English title>
- **GitHub:** <umbrella issue / closing PR>
- **Period:** <start date> → <close date>
- **Author:** <who>

## 1. Summary and business value

<What shipped, in two paragraphs. What the company can now do that it could not before.>

## 2. Scope — planned, completed, deferred

<The original scope; what actually completed; what was deferred and WHERE it went (bead /
issue references). Explicitly list any documentation rows skipped per 039-DR-STND § 2 and
why.>

## 3. Architecture and tradeoffs

<What was built and the shape it took. Every real alternative considered and why it lost —
"chose X over Y because Z". Interfaces/schemas exposed for future phases (ADR-000
Article III partial-enablement calls, made explicitly).>

## 4. Verification evidence

<What was tested/drilled and the LINKED evidence — CI runs, drill transcripts, logs,
before/after measurements. "Verified" without a link does not count.>

## 5. Issues and root causes

<What went wrong during the work, each traced to a root cause — not the proximate symptom.>

## 6. Lessons learned

<What we'd do differently; which lessons became standing rules, and where those rules now
live (CLAUDE.md section, standard, hook, CI gate).>

## 7. Operational impact, including cost

<New/changed automations (with their mission-control/automations.md registry rows),
RAM/disk/runtime footprint, money cost delta, on-call/attention burden delta.>

## 8. Rollback procedure and validation

<How to undo this epic's changes, and the evidence the rollback path was actually
exercised — or the argued reason exercising it is impractical.>

## 9. Next steps

<The recommended follow-on work, dependency-ordered, each with its bead/issue reference.>
