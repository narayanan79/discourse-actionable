# frozen_string_literal: true

module DiscourseActionable
  # Mirrors core's `most_liked_by_users` / `most_liked_users` for actionables.
  # Results are memoized because the serializer reads each list twice (include
  # condition + value).
  module UserSummaryExtension
    extend ActiveSupport::Concern

    def actionable_given
      @user.user_stat&.actionable_given || 0
    end

    def actionable_received
      @user.user_stat&.actionable_received || 0
    end

    def most_actionabled_by_users
      @most_actionabled_by_users ||= user_counts(actionable_counts_by_giver)
    end

    def most_actionabled_users
      @most_actionabled_users ||= user_counts(actionable_counts_by_receiver)
    end

    private

    def actionable_counts_by_giver
      UserAction
        .joins(:target_topic, :target_post)
        .merge(Topic.listable_topics.visible.secured(@guardian))
        .where(user: @user)
        .where(action_type: DiscourseActionable::USER_ACTION_RECEIVED)
        .group(:acting_user_id)
        .order("COUNT(*) DESC")
        .limit(UserSummary::MAX_SUMMARY_RESULTS)
        .pluck("acting_user_id, COUNT(*)")
        .to_h
    end

    def actionable_counts_by_receiver
      UserAction
        .joins(:target_topic, :target_post)
        .merge(Topic.listable_topics.visible.secured(@guardian))
        .where(action_type: DiscourseActionable::USER_ACTION_RECEIVED)
        .where(acting_user_id: @user.id)
        .group(:user_id)
        .order("COUNT(*) DESC")
        .limit(UserSummary::MAX_SUMMARY_RESULTS)
        .pluck("user_actions.user_id, COUNT(*)")
        .to_h
    end
  end
end
