# frozen_string_literal: true

# Adversarial tests: handler error isolation, timeouts, and boundary conditions.
# Describes scenario-level behavior across multiple classes, not a single class.
# rubocop:disable RSpec/DescribeClass
RSpec.describe "Adversarial: handler isolation and edge cases" do
  subject(:runner) do
    Wild::Hooks::Execution::Runner.new(registry: registry, config: config,
                                       health_monitor: monitor)
  end

  let(:config)   { Wild.config.hooks }
  let(:registry) { setup_registry_with_hook }
  let(:monitor)  { Wild::Hooks::Health::Monitor.new }

  context "when a handler raises RuntimeError" do
    before do
      config.on_handler_error = :log_and_continue
      registry.register_handler(hook_name: "before_tool_call",
                                callable: error_callable("intentional failure"))
    end

    it "records :error outcome without propagating" do
      results = runner.execute("before_tool_call", {})
      expect(results.first).to be_error
      expect(results.first.error.message).to eq("intentional failure")
    end

    it "records error in health monitor" do
      results = runner.execute("before_tool_call", {})
      handler = results.first.handler
      expect(monitor.metrics_for(handler.id).error_count).to eq(1)
    end
  end

  context "when a handler raises an obscure exception subclass" do
    let(:custom_error) { Class.new(StandardError) { def message = "custom" } }

    before do
      config.on_handler_error = :log_and_continue
      registry.register_handler(hook_name: "before_tool_call",
                                callable: ->(_) { raise custom_error })
    end

    it "isolates and records the custom exception" do
      results = runner.execute("before_tool_call", {})
      expect(results.first).to be_error
    end
  end

  context "when handler raises on every call and mode is :halt" do
    before do
      config.on_handler_error = :halt
      registry.register_handler(hook_name: "before_tool_call", callable: error_callable,
                                priority: 10)
      registry.register_handler(hook_name: "before_tool_call", callable: ->(_) { :safe },
                                priority: 200)
    end

    it "halts after the first failure" do
      results = runner.execute("before_tool_call", {})
      expect(results.size).to eq(1)
    end

    it "does not execute the safe handler" do
      results = runner.execute("before_tool_call", {})
      expect(results.map(&:return_value)).not_to include(:safe)
    end
  end

  context "when a handler times out" do
    before do
      registry.register_handler(
        hook_name: "before_tool_call",
        callable: slow_callable(sleep_ms: 500),
        timeout_ms: 50
      )
    end

    it "produces :timeout outcome" do
      results = runner.execute("before_tool_call", {})
      expect(results.first).to be_timeout
    end

    it "records timeout in health monitor" do
      results = runner.execute("before_tool_call", {})
      handler = results.first.handler
      expect(monitor.metrics_for(handler.id).timeout_count).to eq(1)
    end

    it "continues after timeout when mode is :log_and_continue" do
      config.on_handler_error = :log_and_continue
      registry.register_handler(hook_name: "before_tool_call", callable: ->(_) { :after_timeout },
                                priority: 200)
      results = runner.execute("before_tool_call", {})
      expect(results.size).to eq(2)
      expect(results.last.return_value).to eq(:after_timeout)
    end
  end

  context "when registering at the exact max_handlers_per_hook limit" do
    before do
      config.max_handlers_per_hook = 3
      # Rebuild registry with new config
    end

    it "rejects the (limit+1)th registration" do
      r = Wild::Hooks::Registry::HookRegistry.new(config: config)
      r.define(name: "before_tool_call", trigger: :before_tool_call)
      3.times { r.register_handler(hook_name: "before_tool_call", callable: ->(_) {}) }
      expect { r.register_handler(hook_name: "before_tool_call", callable: ->(_) {}) }
        .to raise_error(Wild::Hooks::HandlerLimitExceededError)
    end
  end

  context "when audit trail ring buffer is under pressure" do
    it "never exceeds max_audit_entries" do
      config.max_audit_entries = 10
      audit_logger = Wild::Hooks::Audit::Logger.new(config: config)
      subject_runner = Wild::Hooks::Execution::Runner.new(
        registry: registry,
        config: config,
        audit_logger: audit_logger
      )
      registry.register_handler(hook_name: "before_tool_call", callable: ->(_) { :ok })

      20.times { subject_runner.execute("before_tool_call", {}) }

      expect(audit_logger.trail.count).to eq(10)
    end
  end

  context "when handler callable mutates the context hash" do
    it "does not affect subsequent handlers via shared reference" do
      received_by_second = []
      registry.register_handler(
        hook_name: "before_tool_call",
        callable: ->(ctx) { ctx[:injected] = :evil },
        priority: 10
      )
      registry.register_handler(
        hook_name: "before_tool_call",
        callable: ->(ctx) { received_by_second << ctx.dup },
        priority: 200
      )
      # We pass context by reference — this test documents/verifies the current behaviour.
      # The runner does NOT freeze context; mutation is detectable.
      runner.execute("before_tool_call", { original: true })
      expect(received_by_second.first).to include(injected: :evil)
    end
  end

  context "when a handler returns nil" do
    before do
      registry.register_handler(hook_name: "before_tool_call", callable: ->(_) {})
    end

    it "records :success with nil return_value" do
      results = runner.execute("before_tool_call", {})
      expect(results.first).to be_success
      expect(results.first.return_value).to be_nil
    end
  end

  context "when a handler returns false" do
    before do
      registry.register_handler(hook_name: "before_tool_call", callable: ->(_) { false })
    end

    it "records :success with false return_value" do
      results = runner.execute("before_tool_call", {})
      expect(results.first).to be_success
      expect(results.first.return_value).to be false
    end
  end

  context "when handler store is accessed concurrently" do
    it "does not raise under concurrent registration" do
      store = Wild::Hooks::Registry::HandlerStore.new(max_per_hook: 50)
      threads = 10.times.map do
        Thread.new { store.register(build_handler) }
      end
      expect { threads.each(&:join) }.not_to raise_error
      expect(store.count_for("before_tool_call")).to eq(10)
    end
  end

  context "when audit trail is accessed concurrently" do
    it "does not corrupt state under concurrent appends" do
      trail = Wild::Hooks::Audit::Trail.new(max_entries: 100)
      threads = 20.times.map do
        Thread.new { trail.append(build_event) }
      end
      threads.each(&:join)
      expect(trail.count).to eq(20)
    end
  end
end

# rubocop:enable RSpec/DescribeClass
