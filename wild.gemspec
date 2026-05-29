# frozen_string_literal: true

require_relative "lib/wild/version"

Gem::Specification.new do |spec|
  spec.name        = "wild"
  spec.version     = Wild::VERSION
  spec.authors     = ["Jeremy Longshore"]
  spec.email       = ["jeremy@jeremylongshore.com"]

  spec.summary     = "Rails engine + generator for safe, capability-gated AI-agent operations inside a Rails app."
  spec.description = <<~DESC
    wild is a single Rails engine gem that hosts ten Wild::* namespaces — introspection,
    admin tools, capability gate, telemetry (collector/pipeline/analysis), hooks,
    analyzers (permission/test flakes), and skillops. One install, one generator, one
    configuration block, one CHANGELOG, one CI. Consolidates ten previously-separate
    jeremylongshore/wild-* gems after a unanimous 7-seat thinker council rejection of
    the ten-gem topology. See 000-docs/adr/ADR-0001-topology.md for the canonical decision.
  DESC

  spec.homepage    = "https://github.com/jeremylongshore/wild"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "documentation_uri" => "#{spec.homepage}/blob/main/README.md",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.start_with?("spec/", ".github/", "000-docs/", ".gitignore", ".gitattributes",
                    ".editorconfig", ".rubocop.yml", "packwerk.yml", "codecov.yml",
                    "Gemfile", "Rakefile")
    end
  end

  spec.bindir        = "bin"
  spec.executables   = %w[wild-mcp-introspection wild-mcp-admin]
  spec.require_paths = ["lib"]

  # Runtime
  spec.add_dependency "rails", ">= 7.1"

  # Development (alphabetical — Gemspec/OrderedDependencies)
  spec.add_development_dependency "brakeman", "~> 8.0"
  spec.add_development_dependency "bundler-audit", "~> 0.9"
  spec.add_development_dependency "packwerk", "~> 3.2"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rspec-rails", "~> 6.1"
  spec.add_development_dependency "rubocop", "~> 1.65"
  spec.add_development_dependency "rubocop-rails", "~> 2.25"
  spec.add_development_dependency "rubocop-rspec", "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.22"
  # simplecov-cobertura 2.x has a Malformed XML self-parse bug. 3.x fixes it.
  spec.add_development_dependency "simplecov-cobertura", "~> 3.1"
  spec.add_development_dependency "sqlite3", "~> 2.0"
end
