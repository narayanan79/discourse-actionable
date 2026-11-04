# frozen_string_literal: true

module DiscourseActionable
  # Core's generic `/post_actions` endpoint accepts any `post_action_type_id`.
  # Type 50 is unknown to core's flag-based type registry, so core would create
  # actionable PostActions while skipping every rule and all bookkeeping this
  # plugin enforces (own posts, trust level, closed topics, daily limit,
  # user stats). Actionables must go through `/actionable/:post_id` instead.
  module PostActionsControllerExtension
    private

    def fetch_post_action_type_id_from_params
      super
      if @post_action_type_id == DiscourseActionable::POST_ACTION_TYPE_ID
        raise Discourse::InvalidAccess
      end
    end
  end
end
