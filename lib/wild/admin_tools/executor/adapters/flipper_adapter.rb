# frozen_string_literal: true

module Wild
  module AdminTools
    module Executor
      module Adapters
        class FlipperAdapter < FlagAdapter
          def read_flag(flag_name)
            require_flipper!
            feature = Flipper[flag_name.to_sym]
            return nil unless feature_exists?(flag_name)

            {
              name: flag_name,
              enabled: feature.enabled?,
              percentage: extract_percentage(feature),
              actors: extract_actors(feature),
              gates: feature.gates_hash
            }
          end

          def list_flags(filter: nil, enabled_only: false, limit: 100)
            require_flipper!
            features = Flipper.features.to_a
            features = features.select { |f| f.name.to_s.include?(filter) } if filter
            features = features.select(&:enabled?) if enabled_only
            features.first(limit).map { |f| serialize_flag(f) }
          end

          def toggle_flag!(flag_name, enabled)
            require_flipper!
            feature = Flipper[flag_name.to_sym]
            if enabled
              feature.enable
            else
              feature.disable
            end
            { flag_name: flag_name, enabled: enabled }
          end

          def enable_for_actor!(flag_name, actor_type, actor_id)
            require_flipper!
            actor = Flipper::Actor.new("#{actor_type};#{actor_id}")
            Flipper[flag_name.to_sym].enable_actor(actor)
            { flag_name: flag_name, actor_type: actor_type, actor_id: actor_id, enabled: true }
          end

          def disable_for_actor!(flag_name, actor_type, actor_id)
            require_flipper!
            actor = Flipper::Actor.new("#{actor_type};#{actor_id}")
            Flipper[flag_name.to_sym].disable_actor(actor)
            { flag_name: flag_name, actor_type: actor_type, actor_id: actor_id, enabled: false }
          end

          def enable_percentage!(flag_name, percentage)
            require_flipper!
            Flipper[flag_name.to_sym].enable_percentage_of_actors(percentage)
            { flag_name: flag_name, percentage: percentage }
          end

          def delete_flag!(flag_name)
            require_flipper!
            Flipper.remove(flag_name.to_sym)
            { flag_name: flag_name, deleted: true }
          end

          private

          def require_flipper!
            require "flipper"
          rescue LoadError
            raise AdapterError, "Flipper gem is not available. Add flipper to your Gemfile."
          end

          def feature_exists?(flag_name)
            Flipper.features.any? { |f| f.name.to_s == flag_name.to_s }
          end

          def extract_percentage(feature)
            gate = feature.gates.find { |g| g.is_a?(Flipper::Gates::PercentageOfActors) }
            gate&.wrap(feature.gates_hash[gate.key])&.value
          end

          def extract_actors(feature)
            gate = feature.gates.find { |g| g.is_a?(Flipper::Gates::Actor) }
            return [] unless gate

            Array(feature.gates_hash[gate.key])
          end

          def serialize_flag(feature)
            {
              name: feature.name.to_s,
              enabled: feature.enabled?,
              state: feature.state.to_s
            }
          end
        end
      end
    end
  end
end
