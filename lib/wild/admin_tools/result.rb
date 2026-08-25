# frozen_string_literal: true

module Wild
  module AdminTools
    Result = Data.define(
      :status,
      :action,
      :operation,
      :data,
      :before_snapshot,
      :after_snapshot,
      :metadata
    ) do
      # rubocop:disable Metrics/ParameterLists
      def initialize(status:, action:, operation:, data: {}, before_snapshot: nil, after_snapshot: nil, metadata: {})
        super
      end
      # rubocop:enable Metrics/ParameterLists

      def success?
        status == :success
      end

      def preview?
        status == :preview
      end

      def denied?
        status == :denied
      end

      def error?
        status == :error
      end
    end

    # Metadata keys that must never reach the client-facing response shape but
    # ARE preserved for the audit trail. Currently just the nonce denial
    # path's discriminator (not_found/expired/already_used/mismatch, see
    # guard/nonce_manager.rb Security Decision 8): the client only ever sees
    # the opaque :reason. Server::ResponseFormatter strips this set from
    # every result status; Audit::Recorder reads it. One shared constant so
    # the two never drift apart (security-review follow-up on f-l10-6,
    # PR #73).
    #
    # NOTE: this is assigned outside the Data.define block on purpose:
    # constant assigned inside that block resolves to this file's lexical
    # scope (Wild::AdminTools), not to the Result class itself, and would
    # silently become Wild::AdminTools::AUDIT_ONLY_METADATA_KEYS instead of
    # Wild::AdminTools::Result::AUDIT_ONLY_METADATA_KEYS.
    Result::AUDIT_ONLY_METADATA_KEYS = %i[internal_reason].freeze
  end
end
