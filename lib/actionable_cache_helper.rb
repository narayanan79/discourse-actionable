# frozen_string_literal: true

module ActionableCacheHelper
  # Core caches each user summary for an hour, separately for every viewer
  # (`UsersController#summary_cache_key`), so the cached copies cannot all be
  # listed and deleted. Instead, each user has a version number that is part of
  # the cache key (see `DiscourseActionable::UsersControllerExtension`). Bumping
  # it makes every viewer's copy of that user's summary miss the cache.
  #
  # The version only ever grows while its Redis key exists, so an old copy can
  # never become current again. The key expires a day after the last bump; a
  # summary cached under the restarted version 0 cannot exist by then, because
  # cache entries live for an hour.
  VERSION_TTL = 1.day

  def self.invalidate_user_summary_cache(*user_ids)
    user_ids.flatten.compact.uniq.each do |user_id|
      key = version_key(user_id)
      Discourse.redis.incr(key)
      Discourse.redis.expire(key, VERSION_TTL.to_i)
    end
  end

  def self.summary_version(user_id)
    Discourse.redis.get(version_key(user_id)).to_i
  end

  def self.version_key(user_id)
    "actionable_summary_version:#{user_id}"
  end
end
