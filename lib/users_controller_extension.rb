# frozen_string_literal: true

module DiscourseActionable
  # Adds the user's summary version to core's per-viewer summary cache key, so a
  # mark, unmark or like shows up at once for every viewer (see
  # ActionableCacheHelper).
  module UsersControllerExtension
    private

    def summary_cache_key(user)
      "#{super}:actionable#{ActionableCacheHelper.summary_version(user.id)}"
    end
  end
end
