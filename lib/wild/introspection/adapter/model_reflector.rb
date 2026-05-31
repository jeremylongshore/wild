# frozen_string_literal: true

module Wild
  module Introspection
    module Adapter
      module ModelReflector
        DENIAL_RESPONSE = {
          status: :denied,
          reason: :model_not_allowed,
          message: "The requested model is not on the access allowlist."
        }.freeze

        def self.reflect(model_name)
          metadata = ModelResolver.resolve(model_name)
          return DENIAL_RESPONSE unless metadata

          { status: :ok, model: metadata }
        end
      end
    end
  end
end
