# frozen_string_literal: true

# Wild::Telemetry::Pipeline — Tier 1 per ADR-0003. Transcript ingestion +
# normalization: parses raw agent transcripts (Claude Code / MCP logs / generic)
# via adapters, normalizes turns, detects intents, extracts tool references,
# and redacts for privacy.
#
# Reads its policy from Wild.config.telemetry.pipeline. Code moved from the
# old wild-transcript-pipeline gem in Role 5 PR-9 (second of three Telemetry
# sub-namespace moves).
#
# Deferred behavior changes tracked under wild-rvv.5's children (F7/F8/
# MIN-Kleppmann/F6).

# Models
require "wild/telemetry/pipeline/models/turn"
require "wild/telemetry/pipeline/models/intent"
require "wild/telemetry/pipeline/models/tool_reference"
require "wild/telemetry/pipeline/models/transcript"
require "wild/telemetry/pipeline/models/transcript_batch"

# Ingestion adapters
require "wild/telemetry/pipeline/ingestion/base_adapter"
require "wild/telemetry/pipeline/ingestion/claude_code_adapter"
require "wild/telemetry/pipeline/ingestion/mcp_log_adapter"
require "wild/telemetry/pipeline/ingestion/generic_adapter"

# Normalization
require "wild/telemetry/pipeline/normalization/turn_normalizer"
require "wild/telemetry/pipeline/normalization/intent_detector"
require "wild/telemetry/pipeline/normalization/tool_extractor"

# Privacy
require "wild/telemetry/pipeline/privacy/content_filter"
require "wild/telemetry/pipeline/privacy/metadata_redactor"
require "wild/telemetry/pipeline/privacy/redactor"

# Export — flagged for F6 wire-or-delete audit under wild-rvv.5.4.
require "wild/telemetry/pipeline/export/json_exporter"
require "wild/telemetry/pipeline/export/markdown_exporter"

module Wild
  module Telemetry
    module Pipeline
      class << self
        # Convenience: run the full pipeline on raw input. Returns an array of
        # normalized, redacted Transcript objects.
        def process(input, adapter:, source_id: nil, config: Wild.config.telemetry.pipeline)
          transcripts = adapter.parse(input, source_id: source_id)
          pipe = build_pipeline
          transcripts.map { |t| run_pipeline(t, pipe, config) }
        end

        private

        def build_pipeline
          {
            normalizer: Normalization::TurnNormalizer.new,
            intent_detector: Normalization::IntentDetector.new,
            tool_extractor: Normalization::ToolExtractor.new,
            redactor: Privacy::Redactor.new
          }
        end

        # Redacts exactly once: #redact_transcript below already redacts every
        # turn (plus transcript-level metadata) via Redactor#redact_turn, so
        # turns are intentionally left unredacted going into intent/tool
        # extraction rather than redacted here AND again by redact_transcript
        # (f-l03-1 item 7: the double pass was non-idempotent for markers that
        # happen to match a pattern, and did the redaction work twice).
        #
        # Redaction is the LAST step that touches any field that gets
        # exported: intent_detector and tool_extractor run upstream of it on
        # unredacted turns (by design, see above), so any field they derive
        # from turn content, e.g. Intent#description, is redacted inside
        # #redact_transcript, not here, to keep that single boundary complete
        # (f-l03-1 security-review follow-up: a derived Intent#description
        # copied a raw content slice past this boundary).
        def run_pipeline(transcript, pipe, config)
          turns = pipe[:normalizer].normalize(transcript.turns, config: config)
          intents = pipe[:intent_detector].detect(turns, config: config)
          tool_refs = pipe[:tool_extractor].extract(turns)
          enriched = build_enriched_transcript(transcript, turns, intents, tool_refs)
          pipe[:redactor].redact_transcript(enriched, config: config)
        end

        def build_enriched_transcript(transcript, turns, intents, tool_refs)
          Models::Transcript.new(
            source_type: transcript.source_type,
            source_id: transcript.source_id,
            turns: turns,
            intents: intents,
            tool_references: tool_refs,
            metadata: transcript.metadata.merge(processed: true),
            created_at: transcript.created_at
          )
        end
      end
    end
  end
end
