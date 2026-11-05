# frozen_string_literal: true

module DiscourseActionable
  # Single source of truth for who may mark a post as actionable. Used by the
  # create service's policy and by the `can_toggle_actionable` serializer field
  # so the button state always matches what the server will accept.
  module GuardianExtension
    def can_mark_post_actionable?(post)
      return false if !SiteSetting.actionable_enabled
      return false if !authenticated? || is_anonymous?
      return false if post.blank? || post.trashed?
      # Mirrors core's rule for likes: posts without an author cannot be acted on,
      # and there would be nobody to credit with an "actionable received".
      return false if post.user.blank? || is_my_own?(post)

      topic = post.topic
      return false if topic.blank? || topic.archived? || topic.closed?
      return false if !can_see_post?(post)

      # Plain comparison keeps the historical semantics (no staff bypass) and,
      # unlike `has_trust_level?`, never raises on an out-of-range setting.
      @user.trust_level.to_i >= SiteSetting.actionable_min_trust_level.to_i
    end
  end
end
