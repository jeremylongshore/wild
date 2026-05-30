# frozen_string_literal: true

# Integration scenario across registry, lifecycle, runner, audit, and health —
# not a single-class spec; assertion count reflects the integration depth.
# rubocop:disable RSpec/DescribeClass, RSpec/MultipleExpectations
RSpec.describe "Full hook lifecycle integration" do
  let(:registry) { Wild::Hooks::Registry::HookRegistry.new }
  let(:monitor)  { Wild::Hooks::Health::Monitor.new }
  let(:audit_logger) { Wild::Hooks::Audit::Logger.new }
  let(:lifecycle) { Wild::Hooks::Lifecycle::Manager.new(registry: registry) }

  let(:runner) do
    Wild::Hooks::Execution::Runner.new(
      registry: registry,
      audit_logger: audit_logger,
      health_monitor: monitor
    )
  end

  before do
    registry.define(
      name: "before_tool_call",
      trigger: :before_tool_call,
      description: "Fires before any tool call",
      required_permissions: ["tools.execute"]
    )
  end

  it "registers, executes, audits, and tracks health end-to-end" do
    invocations = []
    handler = registry.register_handler(
      hook_name: "before_tool_call",
      callable: lambda { |ctx|
        invocations << ctx[:tool]
        :approved
      }
    )

    results = runner.execute("before_tool_call", { tool: "bash" })

    expect(results.size).to eq(1)
    expect(results.first).to be_success
    expect(results.first.return_value).to eq(:approved)
    expect(invocations).to eq(["bash"])

    expect(audit_logger.trail.count).to eq(1)
    expect(monitor.metrics_for(handler.id).call_count).to eq(1)
  end

  it "handles handler disable mid-run correctly" do
    handler = registry.register_handler(
      hook_name: "before_tool_call",
      callable: ->(_) { :first }
    )
    registry.register_handler(
      hook_name: "before_tool_call",
      callable: ->(_) { :second },
      priority: 200
    )

    lifecycle.disable_handler(handler.id)
    results = runner.execute("before_tool_call", {})

    expect(results.size).to eq(1)
    expect(results.first.return_value).to eq(:second)
  end

  it "deprecating a hook does not affect existing handlers" do
    registry.register_handler(hook_name: "before_tool_call", callable: ->(_) { :ok })
    lifecycle.deprecate_hook("before_tool_call")

    expect(registry.definition_for("before_tool_call")).to be_deprecated
    results = runner.execute("before_tool_call", {})
    expect(results.first).to be_success
  end

  it "health reporter reflects stale handlers" do
    handler = registry.register_handler(hook_name: "before_tool_call", callable: ->(_) {})
    reporter = Wild::Hooks::Health::Reporter.new(monitor: monitor, registry: registry)

    # Never executed — should appear stale
    summary = reporter.summary
    expect(summary[:stale_handlers]).to include(handler.id)

    runner.execute("before_tool_call", {})
    summary_after = reporter.summary
    expect(summary_after[:stale_handlers]).not_to include(handler.id)
  end

  it "audit trail supports querying by hook_name and outcome" do
    registry.register_handler(hook_name: "before_tool_call", callable: ->(_) { :ok })
    registry.define(name: "on_error", trigger: :on_error)
    registry.register_handler(hook_name: "on_error", callable: ->(_) { :handled })

    runner.execute("before_tool_call", { tool: "bash" })
    runner.execute("on_error", { error: "timeout" })

    trail = audit_logger.trail
    expect(trail.for_hook("before_tool_call").size).to eq(1)
    expect(trail.by_outcome(:success).size).to eq(2)
  end

  it "multiple priority-ordered handlers execute in correct sequence" do
    order = []
    [300, 10, 150, 50].each do |p|
      registry.register_handler(
        hook_name: "before_tool_call",
        callable: ->(_) { order << p },
        priority: p
      )
    end

    runner.execute("before_tool_call", {})
    expect(order).to eq([10, 50, 150, 300])
  end

  it "version update is tracked in history" do
    lifecycle.update_version("before_tool_call", "2.0.0")
    lifecycle.update_version("before_tool_call", "3.0.0")

    history = lifecycle.version_history_for("before_tool_call")
    expect(history.map(&:version)).to eq(%w[2.0.0 3.0.0])
  end
end

# rubocop:enable RSpec/DescribeClass, RSpec/MultipleExpectations
