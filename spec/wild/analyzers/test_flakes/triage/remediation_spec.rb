# frozen_string_literal: true

RSpec.describe Wild::Analyzers::TestFlakes::Triage::Remediation do
  subject(:remediation) { described_class.new }

  let(:timing_cause) do
    Wild::Analyzers::TestFlakes::Models::RootCause.new(
      category: :timing_dependent, confidence: 0.8
    )
  end

  let(:external_cause) do
    Wild::Analyzers::TestFlakes::Models::RootCause.new(
      category: :external_dependency, confidence: 0.7
    )
  end

  describe "#suggestions_for" do
    it "returns timing suggestions for timing root cause" do
      suggestions = remediation.suggestions_for([timing_cause])
      expect(suggestions).not_to be_empty
      expect(suggestions.first).to be_a(String)
    end

    it "returns external dependency suggestions" do
      suggestions = remediation.suggestions_for([external_cause])
      expect(suggestions).not_to be_empty
    end

    it "returns unknown suggestions for empty causes" do
      suggestions = remediation.suggestions_for([])
      expect(suggestions).to eq(described_class::SUGGESTIONS[:unknown])
    end

    it "returns unknown suggestions for nil" do
      suggestions = remediation.suggestions_for(nil)
      expect(suggestions).to eq(described_class::SUGGESTIONS[:unknown])
    end

    it "uses primary cause (highest confidence)" do
      low_timing = Wild::Analyzers::TestFlakes::Models::RootCause.new(
        category: :timing_dependent, confidence: 0.2
      )
      high_external = Wild::Analyzers::TestFlakes::Models::RootCause.new(
        category: :external_dependency, confidence: 0.9
      )
      suggestions = remediation.suggestions_for([low_timing, high_external])
      expect(suggestions).to eq(described_class::SUGGESTIONS[:external_dependency])
    end
  end

  describe "#all_suggestions_for" do
    it "combines suggestions from multiple causes" do
      suggestions = remediation.all_suggestions_for([timing_cause, external_cause])
      expect(suggestions.size).to be >= 2
    end

    it "returns at most 6 suggestions" do
      all_causes = Wild::Analyzers::TestFlakes::Models::RootCause::CATEGORIES.map do |cat|
        Wild::Analyzers::TestFlakes::Models::RootCause.new(category: cat, confidence: 0.5)
      end
      suggestions = remediation.all_suggestions_for(all_causes)
      expect(suggestions.size).to be <= 6
    end

    it "returns unique suggestions" do
      suggestions = remediation.all_suggestions_for([timing_cause, external_cause])
      expect(suggestions).to eq(suggestions.uniq)
    end
  end
end
