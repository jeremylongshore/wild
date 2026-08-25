# frozen_string_literal: true

RSpec.describe Wild::Hooks::Execution::Runner do
  subject(:runner) { described_class.new(registry: registry, config: config) }

  let(:registry) { setup_registry_with_hook }
  let(:config)   { Wild.config.hooks }

  describe "#execute" do
    context "when hook is not defined" do
      it "raises HookNotFoundError" do
        expect { runner.execute("nonexistent", {}) }
          .to raise_error(Wild::Hooks::HookNotFoundError)
      end
    end

    context "with no handlers registered" do
      it "returns an empty array" do
        results = runner.execute("before_tool_call", {})
        expect(results).to eq([])
      end
    end

    context "with a successful handler" do
      before do
        registry.register_handler(hook_name: "before_tool_call", callable: ->(_) { :done })
      end

      it "returns an array with one successful HookResult" do
        results = runner.execute("before_tool_call", {})
        expect(results.size).to eq(1)
        expect(results.first).to be_success
      end

      it "captures return_value" do
        results = runner.execute("before_tool_call", {})
        expect(results.first.return_value).to eq(:done)
      end

      it "records positive duration_ms" do
        results = runner.execute("before_tool_call", {})
        expect(results.first.duration_ms).to be >= 0
      end
    end

    context "with a failing handler and :log_and_continue" do
      before do
        config.on_handler_error = :log_and_continue
        registry.register_handler(hook_name: "before_tool_call", callable: error_callable)
        registry.register_handler(hook_name: "before_tool_call", callable: ->(_) { :second },
                                  priority: 200)
      end

      it "records :error outcome for the failing handler" do
        results = runner.execute("before_tool_call", {})
        expect(results.first).to be_error
      end

      it "continues executing subsequent handlers" do
        results = runner.execute("before_tool_call", {})
        expect(results.size).to eq(2)
        expect(results.last).to be_success
      end
    end

    context "with a failing handler and :halt" do
      before do
        config.on_handler_error = :halt
        registry.register_handler(hook_name: "before_tool_call", callable: error_callable,
                                  priority: 10)
        registry.register_handler(hook_name: "before_tool_call", callable: ->(_) { :second },
                                  priority: 200)
      end

      it "stops execution after the failing handler" do
        results = runner.execute("before_tool_call", {})
        expect(results.size).to eq(1)
        expect(results.first).to be_error
      end
    end

    context "with a timing-out handler" do
      before do
        registry.register_handler(
          hook_name: "before_tool_call",
          callable: slow_callable(sleep_ms: 500),
          timeout_ms: 50
        )
      end

      it "records :timeout outcome" do
        results = runner.execute("before_tool_call", {})
        expect(results.first).to be_timeout
      end
    end

    context "with handlers sorted by priority" do
      let(:order) { [] }

      before do
        registry.register_handler(hook_name: "before_tool_call",
                                  callable: ->(_) { order << :c },
                                  priority: 300)
        registry.register_handler(hook_name: "before_tool_call",
                                  callable: ->(_) { order << :a },
                                  priority: 10)
        registry.register_handler(hook_name: "before_tool_call",
                                  callable: ->(_) { order << :b },
                                  priority: 100)
      end

      it "executes handlers in ascending priority order" do
        runner.execute("before_tool_call", {})
        expect(order).to eq(%i[a b c])
      end
    end

    context "with disabled handlers" do
      before do
        registry.register_handler(hook_name: "before_tool_call",
                                  callable: ->(_) { :active })
        registry.register_handler(hook_name: "before_tool_call",
                                  callable: ->(_) { :disabled },
                                  enabled: false)
      end

      it "skips disabled handlers" do
        results = runner.execute("before_tool_call", {})
        expect(results.size).to eq(1)
        expect(results.first.return_value).to eq(:active)
      end
    end

    context "when passing context to handlers" do
      it "passes context hash to each handler" do
        callable, received = context_capturing_callable
        registry.register_handler(hook_name: "before_tool_call", callable: callable)
        runner.execute("before_tool_call", { tool: "bash", user: "alice" })
        expect(received.first).to eq({ tool: "bash", user: "alice" })
      end
    end

    context "with audit_logger provided" do
      subject(:runner) do
        described_class.new(registry: registry, config: config, audit_logger: audit_logger)
      end

      let(:audit_logger) { Wild::Hooks::Audit::Logger.new }

      before do
        registry.register_handler(hook_name: "before_tool_call", callable: ->(_) { :ok })
      end

      it "records events to the audit logger" do
        runner.execute("before_tool_call", { tool: "bash" })
        expect(audit_logger.trail.count).to eq(1)
      end
    end

    context "with health_monitor provided" do
      subject(:runner) do
        described_class.new(registry: registry, config: config, health_monitor: monitor)
      end

      let(:monitor) { Wild::Hooks::Health::Monitor.new }

      before do
        registry.register_handler(hook_name: "before_tool_call", callable: ->(_) { :ok })
      end

      it "records metrics to the health monitor" do
        runner.execute("before_tool_call", {})
        expect(monitor.all_metrics.size).to eq(1)
      end
    end

    context "when an observability sink raises (f-l01-2)" do
      subject(:runner) do
        described_class.new(registry: registry, config: config, audit_logger: raising_logger,
                            health_monitor: monitor)
      end

      let(:raising_logger) do
        instance_double(Wild::Hooks::Audit::Logger).tap do |dbl|
          allow(dbl).to receive(:record).and_raise(StandardError, "sink is down")
        end
      end
      let(:monitor) { Wild::Hooks::Health::Monitor.new }

      before do
        registry.register_handler(hook_name: "before_tool_call", callable: ->(_) { :ok })
      end

      it "still returns the handler result instead of aborting the invocation" do
        results = runner.execute("before_tool_call", {})
        expect(results.size).to eq(1)
        expect(results.first).to be_success
        expect(results.first.return_value).to eq(:ok)
      end

      it "does not raise out of #execute" do
        expect { runner.execute("before_tool_call", {}) }.not_to raise_error
      end

      it "still records to a sink that did not raise" do
        runner.execute("before_tool_call", {})
        expect(monitor.all_metrics.size).to eq(1)
      end

      it "records the failure visibly via observability_failures instead of swallowing it" do
        expect { runner.execute("before_tool_call", {}) }
          .to change(runner, :observability_failures).from(0).to(1)
      end

      it "logs the sink failure through the configured audit_logger" do
        configured_logger = instance_double(Logger, error: nil)
        allow(Wild.config).to receive(:audit_logger).and_return(configured_logger)

        runner.execute("before_tool_call", {})

        expect(configured_logger).to have_received(:error).with(/audit_logger observability sink failed/)
      end
    end

    context "when only the health_monitor sink raises (f-l01-2 verifier follow-up 6)" do
      subject(:runner) do
        described_class.new(registry: registry, config: config, audit_logger: audit_logger,
                            health_monitor: raising_monitor)
      end

      let(:audit_logger) { Wild::Hooks::Audit::Logger.new }
      let(:raising_monitor) do
        instance_double(Wild::Hooks::Health::Monitor).tap do |dbl|
          allow(dbl).to receive(:record).and_raise(StandardError, "monitor is down")
        end
      end

      before do
        registry.register_handler(hook_name: "before_tool_call", callable: ->(_) { :ok })
      end

      it "still returns the handler result instead of aborting the invocation" do
        results = runner.execute("before_tool_call", {})
        expect(results.first).to be_success
      end

      it "still records to the sink that did not raise" do
        runner.execute("before_tool_call", {})
        expect(audit_logger.trail.count).to eq(1)
      end

      it "records the failure visibly via observability_failures" do
        expect { runner.execute("before_tool_call", {}) }
          .to change(runner, :observability_failures).from(0).to(1)
      end

      it "logs the sink failure naming health_monitor" do
        configured_logger = instance_double(Logger, error: nil)
        allow(Wild.config).to receive(:audit_logger).and_return(configured_logger)

        runner.execute("before_tool_call", {})

        expect(configured_logger).to have_received(:error).with(/health_monitor observability sink failed/)
      end
    end

    context "when the configured logger itself raises (f-l01-2 verifier follow-up 6)" do
      subject(:runner) do
        described_class.new(registry: registry, config: config, audit_logger: raising_logger)
      end

      let(:raising_logger) do
        instance_double(Wild::Hooks::Audit::Logger).tap do |dbl|
          allow(dbl).to receive(:record).and_raise(StandardError, "sink is down")
        end
      end

      before do
        registry.register_handler(hook_name: "before_tool_call", callable: ->(_) { :ok })

        broken_logger = instance_double(Logger)
        allow(broken_logger).to receive(:error).and_raise(StandardError, "logger is down")
        allow(Wild.config).to receive(:audit_logger).and_return(broken_logger)
      end

      it "does not raise out of #execute" do
        expect { runner.execute("before_tool_call", {}) }.not_to raise_error
      end

      it "still increments observability_failures even though the log line could not be emitted" do
        expect { runner.execute("before_tool_call", {}) }
          .to change(runner, :observability_failures).from(0).to(1)
      end
    end

    context "with no audit_logger configured (verifier follow-up 9)" do
      subject(:runner) do
        described_class.new(registry: registry, config: config, audit_logger: raising_logger)
      end

      let(:raising_logger) do
        instance_double(Wild::Hooks::Audit::Logger).tap do |dbl|
          allow(dbl).to receive(:record).and_raise(StandardError, "sink is down")
        end
      end

      before do
        registry.register_handler(hook_name: "before_tool_call", callable: ->(_) { :ok })
        allow(Wild.config).to receive(:audit_logger).and_return(nil)
      end

      it "warns to stderr instead of dropping the sink failure silently" do
        expect { runner.execute("before_tool_call", {}) }
          .to output(/audit_logger observability sink failed/).to_stderr
      end

      it "includes the hook name and handler id so a multi-handler invocation is attributable" do
        handler_id = registry.handlers_for("before_tool_call").first.id
        expect { runner.execute("before_tool_call", {}) }
          .to output(/hook="before_tool_call".*handler="#{Regexp.escape(handler_id)}"/).to_stderr
      end
    end

    context "when a sink raises Timeout::Error (verifier follow-up 8)" do
      subject(:runner) do
        described_class.new(registry: registry, config: config, audit_logger: timing_out_logger)
      end

      let(:timing_out_logger) do
        instance_double(Wild::Hooks::Audit::Logger).tap do |dbl|
          allow(dbl).to receive(:record).and_raise(Timeout::Error, "sink hung")
        end
      end

      before do
        registry.register_handler(hook_name: "before_tool_call", callable: ->(_) { :ok })
      end

      it "propagates Timeout::Error out of #execute instead of counting it as an observability failure" do
        expect { runner.execute("before_tool_call", {}) }.to raise_error(Timeout::Error)
      end
    end
  end
end
