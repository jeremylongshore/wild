# frozen_string_literal: true

module Wild
  # Last-resort reporting for failures in audit and observability sinks.
  #
  # This is deliberately a root-package utility: Hooks and Telemetry cannot
  # depend on CapabilityGate, but all three need the same never-raise,
  # never-silently-drop behavior when their configured logger is unavailable.
  module AuditFailureLog
    class << self
      def record(tag:, error:, detail:, level: :error, suffix: nil)
        line = build_line(tag: tag, error: error, detail: detail, suffix: suffix)
        logger = Wild.config.audit_logger

        if logger.respond_to?(level)
          logger.public_send(level, line)
        else
          write_stderr(line)
        end
      rescue StandardError
        # A broken logger must not turn an already-isolated audit failure into
        # an application failure. Reuse the line if it was safely built; the
        # class-only fallback avoids asking a pathological exception for its
        # message a second time.
        write_stderr(line || "[wild:#{safe_tag(tag)}] audit failure: #{safe_class(error)}")
      end

      private

      def build_line(tag:, error:, detail:, suffix:)
        "[wild:#{safe_tag(tag)}] #{detail}: #{safe_class(error)}: #{safe_message(error)}#{suffix}"
      end

      def safe_tag(tag)
        String(tag)
      rescue StandardError
        "unknown"
      end

      def safe_class(error)
        error.class
      rescue StandardError
        StandardError
      end

      def safe_message(error)
        error.message
      rescue StandardError
        "<unprintable message>"
      end

      # rubocop:disable Style/StderrPuts -- warn is silent when $VERBOSE is nil.
      def write_stderr(line)
        $stderr.puts(line)
      rescue StandardError
        nil
      end
      # rubocop:enable Style/StderrPuts
    end
  end
end
