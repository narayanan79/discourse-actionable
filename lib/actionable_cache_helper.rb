# frozen_string_literal: true

module ActionableCacheHelper
  # Invalidates user summary cache for both giver and receiver
  # Must clear UserSummary instances which internally manage their own caching
  def self.invalidate_user_summary_cache(giver_id, receiver_id)
    # Clear for all possible viewer_id combinations and locales
    [giver_id, receiver_id].each do |user_id|
      [user_id, 0].each do |viewer_id|
        # Discourse caches with locale suffix, so we need to clear all locales
        I18n.available_locales.each do |locale|
          Discourse.cache.delete("user_summary:#{user_id}:#{viewer_id}:#{locale}")
        end
        # Also clear without locale for older cache entries
        Discourse.cache.delete("user_summary:#{user_id}:#{viewer_id}")
      end
    end
  end
end
