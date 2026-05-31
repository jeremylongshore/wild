# frozen_string_literal: true

module Wild
  module AdminTools
    module Identity
      class IdentityExtractor
        def extract(request_context)
          return anonymous_context if request_context.blank?

          caller_id = extract_caller_id(request_context)
          return anonymous_context if caller_id.nil? || caller_id.to_s.strip.empty?

          SessionContext.new(
            caller_id: caller_id.to_s,
            caller_type: extract_caller_type(request_context),
            authenticated: true,
            gate_result: "not_checked"
          )
        end

        private

        def extract_caller_id(context)
          context[:caller_id] || context["caller_id"] ||
            context[:user_id] || context["user_id"] ||
            context[:client_id] || context["client_id"]
        end

        def extract_caller_type(context)
          raw = context[:caller_type] || context["caller_type"] ||
                context[:type] || context["type"]
          (raw || "user").to_s
        end

        def anonymous_context
          SessionContext.new(
            caller_id: nil,
            caller_type: "anonymous",
            authenticated: false,
            gate_result: "not_checked"
          )
        end
      end
    end
  end
end
