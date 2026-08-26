# frozen_string_literal: true

module Wild
  module Analyzers
    module Permission
      module Analyzers
        module WildcardMatcher
          # Bounded cache of compiled Regexp, keyed by the source pattern string.
          # Review wave finding f-l05-1: matches? used to compile a fresh Regexp
          # on every call, ~20x slower than a memoized lookup at realistic scale
          # (500 capabilities x 200 wildcard grants -> ~3.3s uncached vs ~0.17s
          # cached for 300k calls of the same pattern, per the finding's own
          # benchmark). Bounded so a pathological caller feeding unlimited
          # distinct patterns cannot grow this unboundedly; the corpus of real
          # wildcard grants in a given deployment is small and stable, so the
          # cache converges immediately in practice.
          MAX_CACHE_SIZE = 1024
          @regex_cache = {}
          @cache_mutex = Mutex.new

          # Returns true if pattern contains the wildcard metacharacter "*".
          # Review wave finding f-l05-2: this detection was duplicated verbatim
          # (`pattern.include?("*")`) across 6 call sites in this namespace
          # (orphan_analyzer, wildcard_matcher itself, risk_analyzer,
          # shadow_analyzer, consistency_analyzer, models/grant). Centralizing
          # it here means the wildcard grammar lives in exactly one place: any
          # future change to what counts as a wildcard (e.g. adding "?" or
          # "**") only needs to change this method.
          def self.wildcard?(pattern)
            pattern.include?("*")
          end

          # Returns true if pattern matches capability_name.
          # Supports trailing "*" as well as mid-string "*".
          # Examples:
          #   matches?("admin.jobs.*", "admin.jobs.retry")  => true
          #   matches?("admin.jobs.view", "admin.jobs.view") => true
          #   matches?("admin.*", "admin.jobs.retry")        => true
          def self.matches?(pattern, capability_name)
            return capability_name == pattern unless wildcard?(pattern)

            compiled_regex(pattern).match?(capability_name)
          end

          # Given a list of grant capability patterns, return all capability names
          # from the capability set that are covered.
          def self.resolve_patterns(patterns, capability_names)
            capability_names.select do |cap_name|
              patterns.any? { |pattern| matches?(pattern, cap_name) }
            end
          end

          # Compiles (or returns the cached) Regexp for a wildcard pattern.
          # Thread-safe: analyzers may run concurrently across a Report::Builder
          # invocation, and the cache must not race on write.
          def self.compiled_regex(pattern)
            cached = @regex_cache[pattern]
            return cached if cached

            @cache_mutex.synchronize do
              @regex_cache.clear if @regex_cache.size >= MAX_CACHE_SIZE
              @regex_cache[pattern] ||= build_regex(pattern)
            end
          end
          private_class_method :compiled_regex

          def self.build_regex(pattern)
            regex_str = Regexp.escape(pattern).gsub('\\*', ".*")
            Regexp.new("\\A#{regex_str}\\z")
          end
          private_class_method :build_regex
        end
      end
    end
  end
end
