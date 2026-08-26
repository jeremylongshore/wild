# frozen_string_literal: true

require "yaml"

module Wild
  module CapabilityGate
    module Audit
      # Validates an audit event hash against the published JSON Schema
      # (`lib/wild/schemas/capability_gate/audit_event.yml`, draft 2020-12) at
      # emit time (F2, wild-rvv.4.1.2).
      #
      # Pairs with the test-time round-trip conformance spec (wild-rvv.4.1.3):
      # that spec proves representative events conform; this validator proves
      # EVERY event emitted during a dev/test run conforms, catching shapes the
      # representative samples miss.
      #
      # Gem: json_schemer (draft 2020-12). It is a DEVELOPMENT dependency — audit
      # validation defaults on in dev/test, off in prod. A prod consumer that
      # opts in must add json_schemer to their own bundle; #validate! raises a
      # clear ConfigurationError if validation is requested but the gem is absent
      # rather than silently skipping (a silently-skipped validator is a lie).
      module SchemaValidator
        SCHEMA_PATH = File.expand_path(
          "../../schemas/capability_gate/audit_event.yml", __dir__
        )

        class << self
          # Whether emitted audit events should be validated. Reads the live
          # config so tests can flip it per-example. `:auto` (default) → on in
          # dev/test, off in prod (validation costs; a non-conforming event is a
          # developer bug we want surfaced in dev/test, not in production).
          # `true`/`false` force the behaviour regardless of environment.
          #
          # f-l08 addendum item 2: nothing sets `Wild.config.environment` from
          # `Rails.env` (there is no such wiring in Configuration or Engine), so
          # in a real Rails app `Wild.config.environment` silently stays at its
          # :development default even in production — which, combined with
          # `json_schemer` being a DEVELOPMENT-only dependency, would raise on
          # every single evaluation in production. When Rails is loaded (this
          # gem's Engine always `require "rails"`s it) and reports a production
          # environment, that takes priority and forces validation off,
          # regardless of what `Wild.config.environment` happens to hold.
          # Anything other than a real Rails production environment falls back
          # to the existing `Wild.config.environment` behaviour unchanged.
          def enabled?
            case Wild.config.capability_gate.validate_audit_events
            when true then true
            when false then false
            else auto_enabled?
            end
          end

          # Raise Wild::CapabilityGate::AuditSchemaError if `event_hash` does not
          # conform. Returns nil on success. Never call this on the prod hot path
          # unless validation is explicitly enabled — compiling/validating costs.
          def validate!(event_hash)
            errors = schemer.validate(event_hash).map { |e| describe(e) }
            return if errors.empty?

            raise Wild::CapabilityGate::AuditSchemaError,
                  "audit event does not conform to audit_event.yml: #{errors.join("; ")}"
          end

          # rubocop:disable Rails/Delegate -- class-method facade over a memoized private helper, not an instance delegation
          def valid?(event_hash)
            schemer.valid?(event_hash)
          end
          # rubocop:enable Rails/Delegate

          # Probe that the validator is actually usable (compiles/memoizes the
          # schema) WITHOUT validating any particular event. Raises
          # AuditValidatorUnavailableError if `json_schemer` is absent — the
          # same failure `schemer` raises on first real use, just triggered at
          # Gate#initialize (construction time) instead of first #evaluate
          # (f-l08-2 boot-time hardening, item 2b). The first-use raise inside
          # `schemer` stays in place as a backstop for any caller that builds an
          # Evaluator directly, bypassing Gate#initialize.
          def ensure_available!
            schemer
            nil
          end

          # Reset the memoized schemer (test support — after a schema edit).
          def reset!
            @schemer = nil
          end

          private

          # (production => off); anything else falls back to the pre-existing
          # Wild.config.environment check. Rescue defensively — a stubbed or
          # unusual Rails.env must never turn "should validate" into a raise
          # from inside this predicate itself.
          # @api private
          def auto_enabled?
            return false if rails_production?

            %i[development test].include?(Wild.config.environment)
          end

          # @api private
          def rails_production?
            defined?(Rails) && Rails.respond_to?(:env) && Rails.env.production?
          rescue StandardError
            false
          end

          # Compiled schema, memoized — compilation is the expensive step.
          def schemer
            @schemer ||= begin
              require "json_schemer"
              JSONSchemer.schema(YAML.safe_load_file(SCHEMA_PATH, permitted_classes: []))
            rescue LoadError
              raise Wild::CapabilityGate::AuditValidatorUnavailableError,
                    "audit-event validation is enabled but the `json_schemer` gem is not available. " \
                    "Add `gem \"json_schemer\"` to your bundle, or disable validation via " \
                    "`Wild.config.capability_gate.validate_audit_events = false`."
            end
          end

          # Compact, greppable one-liner per validation error.
          def describe(error)
            pointer = error["data_pointer"].to_s
            loc = pointer.empty? ? "(root)" : pointer
            "#{loc} #{error["type"]}"
          end
        end
      end
    end
  end
end
