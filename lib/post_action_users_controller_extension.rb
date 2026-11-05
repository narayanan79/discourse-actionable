# frozen_string_literal: true

module DiscourseActionable
  # Core's "who acted" endpoint (/post_action_users) lists the actors of any
  # post action type it does not know, to anyone who can see the post. For
  # actionables that would bypass `actionable_show_who_actioned` and the login
  # requirement of /actionable/:post_id/who.
  module PostActionUsersControllerExtension
    def index
      if params[:post_action_type_id].to_i == DiscourseActionable::POST_ACTION_TYPE_ID
        raise Discourse::InvalidAccess
      end

      super
    end
  end
end
