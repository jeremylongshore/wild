# frozen_string_literal: true

module Wild
  # Base of the consumer-distinguishable error tree. Armstrong-mandated,
  # council-blessed (~30 LOC).
  #
  # Consumers may rescue at any level:
  #
  #   begin
  #     Wild::AdminTools.invoke!(...)
  #   rescue Wild::CapabilityGate::DeniedError => e
  #     # Specific: user lacks the capability.
  #   rescue Wild::CapabilityGate::Error => e
  #     # Any capability-gate error including evaluation failure.
  #   rescue Wild::Error => e
  #     # Any wild error.
  #   end
  #
  # Internal `rescue` clauses inside wild MUST be specific or re-raise after
  # audit emission (F2 — every error path emits a structured audit event).
  class Error < StandardError; end

  class ConfigurationError < Error; end
end
