# frozen_string_literal: true

module ActionableCacheHelper
  # Must match core's `UsersController#summary_cache_key`:
  #   user_summary:<user_id>:<viewer_id>:<locale>:<auto_translate>
  # The key includes the viewer, so only the cases we can enumerate are cleared:
  # the user viewing their own summary and anonymous viewers. Everyone else sees
  # the regular one-hour cache expiry, as for core like counts.
  AUTO_TRANSLATE_VARIANTS = [true, false].freeze

  def self.invalidate_user_summary_cache(*user_ids)
    keys = summary_cache_keys(user_ids.flatten.compact.uniq)
    return if keys.empty?

    cache = Discourse.cache
    if cache.respond_to?(:redis) && cache.respond_to?(:normalize_key)
      # One round trip instead of one DEL per key/locale.
      cache.redis.del(*keys.map { |key| cache.normalize_key(key) })
    else
      keys.each { |key| cache.delete(key) }
    end
  end

  def self.summary_cache_keys(user_ids)
    locales = I18n.available_locales

    user_ids.flat_map do |user_id|
      [user_id, 0].uniq.flat_map do |viewer_id|
        locales.flat_map do |locale|
          AUTO_TRANSLATE_VARIANTS.map do |auto_translate|
            ["user_summary", user_id, viewer_id, locale, auto_translate].join(":")
          end
        end
      end
    end
  end
end
