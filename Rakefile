# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

# Per-namespace test tasks — Beck Refinement #3 / DHH Week-2 plan
# Each task runs RSpec scoped to one namespace's spec subtree.
WILD_NAMESPACES = %w[
  introspection
  admin_tools
  capability_gate
  telemetry
  hooks
  analyzers
  skillops
].freeze

namespace :test do
  WILD_NAMESPACES.each do |ns|
    desc "Run #{ns} namespace specs"
    RSpec::Core::RakeTask.new(ns.to_sym) do |t|
      t.pattern = "spec/wild/#{ns}/**/*_spec.rb"
    end
  end

  desc "Run engine-level specs"
  RSpec::Core::RakeTask.new(:engine) do |t|
    t.pattern = "spec/engine/**/*_spec.rb"
  end
end

begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new
rescue LoadError
  # RuboCop is a development dependency; tolerate its absence in some contexts.
end

task default: %i[spec rubocop]
