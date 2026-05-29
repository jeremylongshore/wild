# ADR-0002: Namespace extraction policy — when a namespace earns its own gemspec

**Date:** 2026-05-29
**Status:** Accepted
**Deciders:** Jeremy Longshore (sole signer) after thinker council rev2
**Relates to:** ADR-0001 (topology)

## Context

ADR-0001 consolidated ten gems into one `wild` gem with ten namespaces. The
council rev2 verdict explicitly preserved an option: if a real external
consumer with divergent cadence appears for one of the namespaces, that
namespace MAY earn its own gemspec.

The defense's strongest carveouts (Points 7, 10, partial 3) hinged on this
optionality. Without ADR-0002, the consolidation feels final to consumers and
the option goes unexercised when it should fire. ADR-0002 makes the procedure
explicit so future maintainers know **exactly when** a namespace splits out.

## Decision

A namespace inside `wild` earns its own gemspec when **all four** of the
following are true:

1. **External consumer exists.** At least one production codebase outside the
   `jeremylongshore` GitHub namespace has the namespace as a load-bearing
   dependency. "I might use this someday" does not count. "We ship it in our
   product, it's in our Gemfile.lock, and we file issues against it" counts.

2. **Cadence divergence is concrete.** The external consumer's release
   pressure on the namespace differs from `wild`'s release pressure by at least
   one of:
   - The consumer needs a release more than once per `wild` minor cycle, AND
   - The consumer cannot adopt unrelated changes from other namespaces
     between their needed releases.

3. **The namespace's API surface is stable.** No `# @api private` symbols
   remain in the namespace's public surface. The CHANGELOG section for the
   namespace has had a full minor-version cycle without breaking changes.

4. **A maintainer commits to the split.** The extraction requires:
   - A new `jeremylongshore/wild-<namespace>` repo
   - The namespace's `lib/wild/<namespace>/` tree copied to the new repo's
     `lib/wild/<namespace>/`
   - A thin shim left in `wild` that requires the extracted gem and re-exports
     the namespace constants
   - One published version of the new gem with the same semantics as the
     current namespace
   - An amendment to ADR-0001 listing the extracted namespace

If any of the four is missing, the namespace **stays** inside `wild`.

## Anti-criteria (extraction is forbidden when)

- The motivation is "smaller gem footprint feels better." Aesthetic preference
  is not an external consumer.
- The motivation is internal refactoring. Internal coupling is a Packwerk
  problem solved inside `wild`, not a packaging problem.
- The motivation is "the namespace will probably get external users someday."
  Speculative infrastructure. Council rev2 § "Acknowledged tradeoff" applies.
- The motivation is to make a future marketplace listing look bigger. The
  user has explicitly deferred marketplace concerns past v0.1.0.

## Procedure when criteria are met

1. **File an ADR** amending ADR-0001 with the extraction proposal. Reference
   the four criteria with concrete evidence for each.
2. **PR review by CODEOWNERS** (currently `@jeremylongshore`).
3. **Create the new repo** at `jeremylongshore/wild-<namespace>` using
   `/repo-dress` (or the current canonical repo scaffolder).
4. **Migrate the namespace tree** preserving git history if possible
   (`git subtree split` or equivalent).
5. **Leave a shim** in `wild`:
   ```ruby
   # lib/wild/<namespace>.rb
   begin
     require "wild-<namespace>"
   rescue LoadError
     warn "Wild::<Namespace> moved to its own gem. Add `wild-<namespace>` to your Gemfile."
     raise
   end
   ```
6. **CHANGELOG the move** under `wild`'s next minor version + the new gem's
   v0.1.0. Mark the `wild` namespace section as "Extracted; see wild-<namespace>".
7. **Update the README** to list the namespace as "available standalone."
8. **Sunset window:** the shim ships in `wild` for at least one minor cycle so
   consumers can migrate their Gemfile. Then remove the shim in the next minor.

## What the extracted gem inherits

- Same namespace constant tree (`Wild::<Namespace>`)
- Same configuration surface (registers with `Wild::Configuration` via an
  `initializer` block at gem load)
- Same audit-event emission contract
- Same SemVer commitments (the namespace's CHANGELOG section history becomes
  the new gem's CHANGELOG seed)
- Same `# @api private` discipline

The extracted gem does NOT get to redefine the namespace's public API on day
one. Compatibility with the last `wild` version that shipped the namespace
inline is mandatory.

## Re-merging

If an extracted gem becomes underused (`< 3` external consumers for two
consecutive minor cycles), the maintainer MAY re-merge it back into `wild`
via the inverse procedure. Re-merge requires its own ADR amendment.

## Consequences

### Positive

- Extraction is reversible — the council's "optionality without paying
  coordination tax up front" is preserved.
- The four criteria are concrete enough that a future Claude session or
  contributor can read them and decide without re-litigation.
- Aesthetic / speculative extractions are blocked by the anti-criteria, which
  protects the council's central "no premature splits" finding.

### Negative

- The maintainer must police "external consumer" claims honestly. A bad-faith
  extraction request that ticks the four boxes superficially could still
  land. Mitigated by the ADR amendment + PR review gate.

### Neutral

- The MCP `bin/` scripts (`wild-mcp-introspection`, `wild-mcp-admin`) are NOT
  candidates for extraction under this ADR — they ship as scripts inside
  `wild`. The marketplace path for those is the `plugins/wild/` directory
  (Phase 3 of the build plan), not separate gems.

## Provenance

- ADR-0001 (this ADR's parent)
- Council rev2 verdict §"Final council recommendation" Option A
- Defense Points 7 + 10 + partial 3 (council rev2 §"Points Jeremy WON in the defense")
- DHH migration plan §"Archive the ten old repos with a README redirect" — extraction is the inverse operation of that archive
