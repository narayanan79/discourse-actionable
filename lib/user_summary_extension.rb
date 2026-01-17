# frozen_string_literal: true

module DiscourseActionable
  module UserSummaryExtension
    extend ActiveSupport::Concern

    def actionable_given
      @user.user_stat&.actionable_given || 0
    end

    def actionable_received
      @user.user_stat&.actionable_received || 0
    end

    def most_actionabled_by_users
      actionabler_users = {}
      UserAction
        .joins(:target_topic, :target_post)
        .merge(Topic.listable_topics.visible.secured(@guardian))
        .where(user: @user)
        .where(action_type: UserAction::ACTIONABLE_RECEIVED)
        .group(:acting_user_id)
        .order("COUNT(*) DESC")
        .limit(UserSummary::MAX_SUMMARY_RESULTS)
        .pluck("acting_user_id, COUNT(*)")
        .each { |l| actionabler_users[l[0]] = l[1] }

      user_counts(actionabler_users)
    end

    def most_actionabled_users
      actionabled_users = {}
      UserAction
        .joins(:target_topic, :target_post)
        .merge(Topic.listable_topics.visible.secured(@guardian))
        .where(action_type: UserAction::ACTIONABLE_RECEIVED)
        .where(acting_user_id: @user.id)
        .group(:user_id)
        .order("COUNT(*) DESC")
        .limit(UserSummary::MAX_SUMMARY_RESULTS)
        .pluck("user_actions.user_id, COUNT(*)")
        .each { |l| actionabled_users[l[0]] = l[1] }

      user_counts(actionabled_users)
    end
  end
end
