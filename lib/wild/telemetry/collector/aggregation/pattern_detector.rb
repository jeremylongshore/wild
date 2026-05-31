# frozen_string_literal: true

require "time"

module Wild
  module Telemetry
    module Collector
      module Aggregation
        class PatternDetector
          def initialize(min_sequence_length: 2, min_occurrence_count: 3, session_gap_seconds: 300)
            @min_sequence_length = min_sequence_length
            @min_occurrence_count = min_occurrence_count
            @session_gap_seconds = session_gap_seconds
          end

          def detect_sequences(events)
            sessions = group_into_sessions(events)
            subsequences = extract_subsequences(sessions)
            build_patterns(subsequences, "sequential")
          end

          def detect_failure_cascades(events)
            failure_events = events.select { |e| %w[error denied].include?(e.outcome) }
            sessions = group_into_sessions(failure_events)
            subsequences = extract_subsequences(sessions)
            build_patterns(subsequences, "failure_cascade")
          end

          private

          def group_into_sessions(events)
            return [] if events.empty?

            per_caller = partition_by_caller(events.sort_by(&:timestamp))
            per_caller.flat_map { |session_events| split_by_gap(session_events) }
          end

          def partition_by_caller(sorted_events)
            sorted_events.group_by(&:caller_id).values
          end

          def split_by_gap(caller_events)
            sessions = [[caller_events.first]]

            caller_events.drop(1).each do |event|
              if (parse_ts(event) - parse_ts(sessions.last.last)) <= @session_gap_seconds
                sessions.last << event
              else
                sessions << [event]
              end
            end

            sessions.select { |s| s.size >= @min_sequence_length }
          end

          def parse_ts(event)
            Time.parse(event.timestamp).to_i
          end

          # rubocop:disable Metrics/AbcSize
          def extract_subsequences(sessions)
            counts = Hash.new { |h, k| h[k] = { count: 0, callers: Set.new } }

            sessions.each do |session|
              actions = session.map(&:action)
              caller_id = session.first.caller_id

              (@min_sequence_length..actions.size).each do |len|
                actions.each_cons(len) do |subseq|
                  counts[subseq][:count] += 1
                  counts[subseq][:callers] << caller_id
                end
              end
            end

            counts
          end
          # rubocop:enable Metrics/AbcSize

          def build_patterns(subsequences, pattern_type)
            subsequences
              .select { |_, data| data[:count] >= @min_occurrence_count }
              .sort_by { |_, data| -data[:count] }
              .map { |sequence, data| pattern_hash(sequence, data, pattern_type) }
          end

          def pattern_hash(sequence, data, pattern_type)
            {
              sequence: sequence,
              occurrence_count: data[:count],
              unique_callers: data[:callers].size,
              pattern_type: pattern_type
            }
          end
        end
      end
    end
  end
end
