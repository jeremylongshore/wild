# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass, RSpec/LeakyLocalVariable, RSpec/ContextWording -- data-driven corpus fence: corpus + matcher are read-only module-level locals; describe names the F4 property, not a class

require "yaml"

# F4 anti-drift fence (wild-rvv.1.2.1, council rev2).
#
# The shared lib/wild/schemas/wildcard_corpus.yml is the single source of truth
# for what counts as a capability-name wildcard. This spec runs the ONE matcher
# that pattern-matches capability names — Wild::Analyzers::Permission's
# WildcardMatcher — against every entry's truth table: every `matches[]` string
# must match, every `non_matches[]` string must not. If the matcher's behaviour
# ever drifts from the documented grammar, this goes red.
#
# CapabilityGate is intentionally exact-match (no capability-name wildcards — see
# the corpus header + grant_spec), so there is no second matcher to cross-check;
# the F4 "two must not disagree" concern is satisfied vacuously by there being
# exactly one capability-name matcher. This is that matcher's fence.
RSpec.describe "F4 wildcard corpus ↔ Wild::Analyzers::Permission matcher" do
  matcher = Wild::Analyzers::Permission::Analyzers::WildcardMatcher
  corpus_path = File.expand_path(
    "../../../../../lib/wild/schemas/wildcard_corpus.yml", __dir__
  )
  corpus = YAML.safe_load_file(corpus_path, permitted_classes: [])

  corpus.fetch("patterns").each do |entry|
    pattern = entry.fetch("pattern")

    context "pattern #{pattern.inspect} (#{entry.fetch("description").split(".").first})" do
      entry.fetch("matches").each do |name|
        it "matches #{name.inspect}" do
          expect(matcher.matches?(pattern, name)).to be(true)
        end
      end

      entry.fetch("non_matches").each do |name|
        it "does not match #{name.inspect}" do
          expect(matcher.matches?(pattern, name)).to be(false)
        end
      end
    end
  end
end

# rubocop:enable RSpec/DescribeClass, RSpec/LeakyLocalVariable, RSpec/ContextWording
