# frozen_string_literal: true

module ActionableCacheHelper
  # Generates cache keys for user summary pages
  # Discourse caches user summaries with format: "user_summary:{user_id}:{viewer_id}"
  # viewer_id = 0 means public view, otherwise it's a specific user viewing
  def self.user_summary_cache_keys(user_id)
    [
      "user_summary:#{user_id}:#{user_id}", # User viewing their own summary
      "user_summary:#{user_id}:0", # Public view of the summary
    ]
  end

  # Invalidates user summary cache for both giver and receiver
  def self.invalidate_user_summary_cache(giver_id, receiver_id)
    keys = user_summary_cache_keys(giver_id) + user_summary_cache_keys(receiver_id)
    keys.each { |key| Discourse.cache.delete(key) }
  end
end
