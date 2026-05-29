# frozen_string_literal: true

module Wild
  # Single canonical version constant. Bumped by the release workflow when
  # cutting a release. Per-namespace SemVer commitments live in CHANGELOG
  # sections, not in separate version constants.
  VERSION = "0.0.1"
end
