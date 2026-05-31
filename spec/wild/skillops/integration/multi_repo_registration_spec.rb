# frozen_string_literal: true

# rubocop:disable Rails/DynamicFindBy, RSpec/DescribeClass, RSpec/ExampleLength

RSpec.describe "Multi-repo skill registration" do
  let(:registry) { Wild::Skillops.build }
  let(:ecosystem_repos) do
    %w[
      wild-rails-safe-introspection-mcp
      wild-admin-tools-mcp
      wild-capability-gate
      wild-session-telemetry
      wild-transcript-pipeline
      wild-gap-miner
      wild-hook-ops
      wild-permission-analyzer
      wild-test-flake-forensics
      wild-skillops-registry
    ]
  end

  def skill_for_repo(repo, index)
    make_skill(
      name: "#{repo.tr("-", ".")}.skill.#{index}",
      description: "Primary skill for #{repo}",
      repo: repo,
      tags: [repo.split("-").last, "ecosystem"],
      category: :workflow
    )
  end

  it "registers one skill per ecosystem repo without conflict" do
    ecosystem_repos.each_with_index do |repo, i|
      skill = skill_for_repo(repo, i)
      registry.registrar.register(skill)
    end
    expect(registry.store.size).to eq(ecosystem_repos.size)
  end

  it "can discover skills from each repo independently" do
    ecosystem_repos.each_with_index do |repo, i|
      registry.registrar.register(skill_for_repo(repo, i))
    end

    ecosystem_repos.each do |repo|
      results = registry.finder.find_by_repo(repo)
      expect(results.size).to eq(1)
    end
  end

  it "shared tag ecosystem appears in all results" do
    ecosystem_repos.each_with_index do |repo, i|
      registry.registrar.register(skill_for_repo(repo, i))
    end

    ecosystem_skills = registry.finder.find_by_tag("ecosystem")
    expect(ecosystem_skills.size).to eq(ecosystem_repos.size)
  end

  it "tracks health independently per repo skill" do
    ecosystem_repos.each_with_index do |repo, i|
      registry.registrar.register(skill_for_repo(repo, i))
    end

    available_repos = ecosystem_repos.first(5)
    degraded_repos  = ecosystem_repos.last(3)

    available_repos.each do |repo|
      name = registry.finder.find_by_repo(repo).first.name
      registry.health_tracker.record(name, state: :available)
    end

    degraded_repos.each do |repo|
      name = registry.finder.find_by_repo(repo).first.name
      registry.health_tracker.record(name, state: :degraded)
    end

    summary = registry.health_aggregator.summary
    expect(summary[:counts][:available]).to eq(5)
    expect(summary[:counts][:degraded]).to eq(3)
    expect(summary[:untracked]).to eq(2)
  end
end

# rubocop:enable Rails/DynamicFindBy, RSpec/DescribeClass, RSpec/ExampleLength
