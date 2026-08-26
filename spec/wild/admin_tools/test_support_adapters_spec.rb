# frozen_string_literal: true

# The three spec/support fakes (TestCacheAdapter, TestJobAdapter,
# TestFlagAdapter) stand in for the concrete adapters throughout the rest of
# the executor/guard/pipeline suite; this file just holds them to the same
# structural contract the concrete adapters are held to, so a future change
# to a test double can't silently drift from the abstract interface it is
# supposed to double for.
RSpec.describe Wild::AdminTools::TestSupport do
  describe Wild::AdminTools::TestSupport::TestCacheAdapter do
    it_behaves_like "an admin tools adapter", Wild::AdminTools::Executor::Adapters::CacheAdapter
  end

  describe Wild::AdminTools::TestSupport::TestJobAdapter do
    it_behaves_like "an admin tools adapter", Wild::AdminTools::Executor::Adapters::JobAdapter
  end

  describe Wild::AdminTools::TestSupport::TestFlagAdapter do
    it_behaves_like "an admin tools adapter", Wild::AdminTools::Executor::Adapters::FlagAdapter
  end
end
