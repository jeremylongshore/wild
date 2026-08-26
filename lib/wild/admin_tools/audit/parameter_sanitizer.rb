# frozen_string_literal: true

require "wild/hooks/audit/sanitizer"

module Wild
  module AdminTools
    module Audit
      # Compatibility name for the shared Hooks audit sanitizer.
      #
      # AdminTools is a Tier 4 consumer of the Tier 1 Hooks substrate, so it
      # must not carry a second redaction grammar. Keeping this subclass
      # preserves the public constructor/injection seam while all key
      # normalization, recursive array handling, hashing, and secret matching
      # are owned by Wild::Hooks::Audit::Sanitizer.
      class ParameterSanitizer < Wild::Hooks::Audit::Sanitizer
      end
    end
  end
end
