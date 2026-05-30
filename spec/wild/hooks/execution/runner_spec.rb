# frozen_string_literal: true

RSpec.describe Wild::Hooks::Execution::Runner do
  subject(:runner) { described_class.new(registry: registry, config: config) }

  let(:registry) { setup_registry_with_hook }
  let(:config)   { Wild.config.hooks }

  describe '#execute' do
    context 'when hook is not defined' do
      it 'raises HookNotFoundError' do
        expect { runner.execute('nonexistent', {}) }
          .to raise_error(Wild::Hooks::HookNotFoundError)
      end
    end

    context 'with no handlers registered' do
      it 'returns an empty array' do
        results = runner.execute('before_tool_call', {})
        expect(results).to eq([])
      end
    end

    context 'with a successful handler' do
      before do
        registry.register_handler(hook_name: 'before_tool_call', callable: ->(_) { :done })
      end

      it 'returns an array with one successful HookResult' do
        results = runner.execute('before_tool_call', {})
        expect(results.size).to eq(1)
        expect(results.first).to be_success
      end

      it 'captures return_value' do
        results = runner.execute('before_tool_call', {})
        expect(results.first.return_value).to eq(:done)
      end

      it 'records positive duration_ms' do
        results = runner.execute('before_tool_call', {})
        expect(results.first.duration_ms).to be >= 0
      end
    end

    context 'with a failing handler and :log_and_continue' do
      before do
        config.on_handler_error = :log_and_continue
        registry.register_handler(hook_name: 'before_tool_call', callable: error_callable)
        registry.register_handler(hook_name: 'before_tool_call', callable: ->(_) { :second },
                                  priority: 200)
      end

      it 'records :error outcome for the failing handler' do
        results = runner.execute('before_tool_call', {})
        expect(results.first).to be_error
      end

      it 'continues executing subsequent handlers' do
        results = runner.execute('before_tool_call', {})
        expect(results.size).to eq(2)
        expect(results.last).to be_success
      end
    end

    context 'with a failing handler and :halt' do
      before do
        config.on_handler_error = :halt
        registry.register_handler(hook_name: 'before_tool_call', callable: error_callable,
                                  priority: 10)
        registry.register_handler(hook_name: 'before_tool_call', callable: ->(_) { :second },
                                  priority: 200)
      end

      it 'stops execution after the failing handler' do
        results = runner.execute('before_tool_call', {})
        expect(results.size).to eq(1)
        expect(results.first).to be_error
      end
    end

    context 'with a timing-out handler' do
      before do
        registry.register_handler(
          hook_name: 'before_tool_call',
          callable: slow_callable(sleep_ms: 500),
          timeout_ms: 50
        )
      end

      it 'records :timeout outcome' do
        results = runner.execute('before_tool_call', {})
        expect(results.first).to be_timeout
      end
    end

    context 'with handlers sorted by priority' do
      let(:order) { [] }

      before do
        registry.register_handler(hook_name: 'before_tool_call',
                                  callable: ->(_) { order << :c },
                                  priority: 300)
        registry.register_handler(hook_name: 'before_tool_call',
                                  callable: ->(_) { order << :a },
                                  priority: 10)
        registry.register_handler(hook_name: 'before_tool_call',
                                  callable: ->(_) { order << :b },
                                  priority: 100)
      end

      it 'executes handlers in ascending priority order' do
        runner.execute('before_tool_call', {})
        expect(order).to eq(%i[a b c])
      end
    end

    context 'with disabled handlers' do
      before do
        registry.register_handler(hook_name: 'before_tool_call',
                                  callable: ->(_) { :active })
        registry.register_handler(hook_name: 'before_tool_call',
                                  callable: ->(_) { :disabled },
                                  enabled: false)
      end

      it 'skips disabled handlers' do
        results = runner.execute('before_tool_call', {})
        expect(results.size).to eq(1)
        expect(results.first.return_value).to eq(:active)
      end
    end

    context 'when passing context to handlers' do
      it 'passes context hash to each handler' do
        callable, received = context_capturing_callable
        registry.register_handler(hook_name: 'before_tool_call', callable: callable)
        runner.execute('before_tool_call', { tool: 'bash', user: 'alice' })
        expect(received.first).to eq({ tool: 'bash', user: 'alice' })
      end
    end

    context 'with audit_logger provided' do
      subject(:runner) do
        described_class.new(registry: registry, config: config, audit_logger: audit_logger)
      end

      let(:audit_logger) { Wild::Hooks::Audit::Logger.new }

      before do
        registry.register_handler(hook_name: 'before_tool_call', callable: ->(_) { :ok })
      end

      it 'records events to the audit logger' do
        runner.execute('before_tool_call', { tool: 'bash' })
        expect(audit_logger.trail.count).to eq(1)
      end
    end

    context 'with health_monitor provided' do
      subject(:runner) do
        described_class.new(registry: registry, config: config, health_monitor: monitor)
      end

      let(:monitor) { Wild::Hooks::Health::Monitor.new }

      before do
        registry.register_handler(hook_name: 'before_tool_call', callable: ->(_) { :ok })
      end

      it 'records metrics to the health monitor' do
        runner.execute('before_tool_call', {})
        expect(monitor.all_metrics.size).to eq(1)
      end
    end
  end
end
