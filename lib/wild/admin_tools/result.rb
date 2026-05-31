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
  end
end
