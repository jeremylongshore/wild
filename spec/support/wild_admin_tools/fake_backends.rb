# frozen_string_literal: true

# Minimal fakes standing in for the Sidekiq and Flipper gems (neither is a
# dependency of wild, and neither is installed in this repo's bundle).
# SidekiqAdapter/FlipperAdapter each lazily `require` their real gem only
# inside the methods that need it; these specs stub that private require
# method to a no-op and `stub_const` the real gem's constant paths with
# these fakes, so the adapters run their actual, unmocked logic against a
# stand-in backend that speaks the same shape the real gem does.
module Wild
  module AdminTools
    module TestSupport
      module FakeSidekiq
        Job = Struct.new(:jid, :queue, :item) do
          def retry
            item["retried"] = true
          end

          def delete
            item["deleted"] = true
          end
        end

        # rubocop:disable Lint/StructNewOverride -- :size intentionally
        # mirrors the real Sidekiq::Queue#size field name; SidekiqAdapter
        # reads it positionally via q.size, never via Struct's own #size.
        QueueEntry = Struct.new(:name, :size, :latency)
        # rubocop:enable Lint/StructNewOverride

        class DeadSet
          class << self
            def jobs
              @jobs ||= []
            end

            def reset!
              @jobs = []
            end
          end

          def find_job(job_id)
            self.class.jobs.find { |j| j.jid == job_id }
          end

          def to_a
            self.class.jobs
          end
        end

        class Queue
          class << self
            def all
              @all ||= []
            end

            def reset!
              @all = []
            end
          end
        end
      end

      module FakeFlipper
        Actor = Struct.new(:value)

        class Feature
          attr_reader :name

          # +registry+ is the fake's back-reference, mirroring how the real
          # Flipper only adds a name to Flipper.features once it has
          # actually been mutated (enabled/disabled/toggled), never merely
          # on `Flipper[:name]` read access. Without this, FlipperAdapter's
          # feature_exists? check (used by #read_flag to return nil for an
          # unknown flag) could never observe "unknown" -- every read would
          # silently auto-vivify a permanent entry first.
          def initialize(name, registry:, enabled: false)
            @name = name
            @registry = registry
            @enabled = enabled
            @actors = []
            @percentage = nil
          end

          def enabled?
            @enabled
          end

          def enable
            @enabled = true
            register!
          end

          def disable
            @enabled = false
            register!
          end

          def enable_actor(actor)
            @actors << actor.value
            register!
          end

          def disable_actor(actor)
            @actors.delete(actor.value)
            register!
          end

          def enable_percentage_of_actors(percentage)
            @percentage = percentage
            register!
          end

          # No PercentageOfActors/Actor gate classes are faked here (they
          # only participate via Ruby's is_a? in the real adapter's
          # extract_percentage/extract_actors helpers), so gates is
          # deliberately empty: both helpers safe-navigate to nil on a
          # gate-less feature, which is a legitimate real-world state
          # (a freshly created, never-toggled flag) and exercises the
          # adapter's read path without hand-rolling Flipper's gate
          # internals.
          def gates
            []
          end

          def gates_hash
            { actors: @actors, percentage: @percentage }
          end

          def state
            enabled? ? :on : :off
          end

          private

          def register!
            @registry.store[@name.to_sym] = self
          end
        end

        class Registry
          class << self
            def store
              @store ||= {}
            end

            # Unlike #store, reading via [] does not persist: a never-toggled
            # name returns a fresh, unregistered Feature each time (see
            # Feature#register!, called only by the mutating methods).
            def [](name)
              store[name.to_sym] || Feature.new(name.to_s, registry: self)
            end

            def features
              store.values
            end

            def remove(name)
              store.delete(name.to_sym)
            end

            def reset!
              @store = {}
            end
          end
        end
      end
    end
  end
end
