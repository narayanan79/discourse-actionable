# frozen_string_literal: true

module DiscourseActionable
  # Resolves the current user's actionable PostAction for the serialized post
  # without extra queries when the topic view has already preloaded the user's
  # post actions (the common case: rendering a topic).
  module PostSerializerExtension
    private

    def actionable_post_action
      return @actionable_post_action if defined?(@actionable_post_action)

      @actionable_post_action = lookup_actionable_post_action
    end

    def lookup_actionable_post_action
      return if scope.user.blank?

      if topic_view || post_actions || all_post_actions
        # Preloaded data covers every post in the view, so a missing entry
        # means "not actioned" rather than "unknown".
        actions&.dig(DiscourseActionable::POST_ACTION_TYPE_ID)
      else
        PostAction.find_by(
          post_id: object.id,
          user_id: scope.user.id,
          post_action_type_id: DiscourseActionable::POST_ACTION_TYPE_ID,
        )
      end
    end
  end
end
