# frozen_string_literal: true

module Wild
  module AdminTools
    module Executor
      class FlagExecutor < Base
        ACTION_MAP = {
          "read_flag" => { preview: :preview_read_flag, execute: :execute_read_flag, operation: "read" },
          "list_flags" => { preview: :preview_list_flags, execute: :execute_list_flags, operation: "read" },
          "toggle_flag" => { preview: :preview_toggle_flag, execute: :execute_toggle_flag, operation: "mutate" },
          "enable_flag_for_actor" => { preview: :preview_enable_flag_for_actor,
                                       execute: :execute_enable_flag_for_actor, operation: "mutate" },
          "disable_flag_for_actor" => { preview: :preview_disable_flag_for_actor,
                                        execute: :execute_disable_flag_for_actor, operation: "mutate" },
          "enable_flag_percentage" => { preview: :preview_enable_flag_percentage,
                                        execute: :execute_enable_flag_percentage, operation: "mutate" },
          "delete_flag" => { preview: :preview_delete_flag, execute: :execute_delete_flag,
                             operation: "mutate_destructive" }
        }.freeze

        private

        def adapter
          Wild::AdminTools.configuration.flag_adapter
        end

        # --- read_flag ---

        def preview_read_flag(params)
          flag = adapter.read_flag(params[:flag_name])
          { flag: flag }
        end

        def execute_read_flag(params)
          adapter.read_flag(params[:flag_name])
        end

        # --- list_flags ---

        def preview_list_flags(params)
          flags = adapter.list_flags(**params.slice(:filter, :enabled_only, :limit))
          { flags: flags, count: flags.size }
        end

        def execute_list_flags(params)
          flags = adapter.list_flags(**params.slice(:filter, :enabled_only, :limit))
          { flags: flags, count: flags.size }
        end

        # --- toggle_flag ---

        def preview_toggle_flag(params)
          flag = adapter.read_flag(params[:flag_name])
          { flag: flag, will_set_enabled: params[:enabled] }
        end

        def execute_toggle_flag(params)
          adapter.toggle_flag!(params[:flag_name], params[:enabled])
        end

        # --- enable_flag_for_actor ---

        def preview_enable_flag_for_actor(params)
          flag = adapter.read_flag(params[:flag_name])
          { flag: flag, actor_type: params[:actor_type], actor_id: params[:actor_id], will_enable: true }
        end

        def execute_enable_flag_for_actor(params)
          adapter.enable_for_actor!(params[:flag_name], params[:actor_type], params[:actor_id])
        end

        # --- disable_flag_for_actor ---

        def preview_disable_flag_for_actor(params)
          flag = adapter.read_flag(params[:flag_name])
          { flag: flag, actor_type: params[:actor_type], actor_id: params[:actor_id], will_disable: true }
        end

        def execute_disable_flag_for_actor(params)
          adapter.disable_for_actor!(params[:flag_name], params[:actor_type], params[:actor_id])
        end

        # --- enable_flag_percentage ---

        def preview_enable_flag_percentage(params)
          flag = adapter.read_flag(params[:flag_name])
          { flag: flag, will_set_percentage: params[:percentage] }
        end

        def execute_enable_flag_percentage(params)
          adapter.enable_percentage!(params[:flag_name], params[:percentage])
        end

        # --- delete_flag ---

        def preview_delete_flag(params)
          flag = adapter.read_flag(params[:flag_name])
          { flag: flag, will_delete: true }
        end

        def execute_delete_flag(params)
          adapter.delete_flag!(params[:flag_name])
        end
      end
    end
  end
end
