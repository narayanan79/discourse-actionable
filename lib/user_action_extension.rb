# frozen_string_literal: true

module DiscourseActionable
  # `UserAction.log_action!` / `remove_action!` call `update_like_count` to keep
  # `user_stats` in sync (skipping private messages). Handle only this plugin's
  # action types and leave every other type, including likes, to core.
  module UserActionExtension
    STAT_COLUMNS = {
      DiscourseActionable::USER_ACTION_GIVEN => "actionable_given",
      DiscourseActionable::USER_ACTION_RECEIVED => "actionable_received",
    }.freeze

    def update_like_count(user_id, action_type, delta)
      column = STAT_COLUMNS[action_type]
      return super if column.nil?

      # Never let a stray decrement push the counter below zero.
      UserStat.where(user_id: user_id).update_all(
        "#{column} = GREATEST(#{column} + #{delta.to_i}, 0)",
      )
    end
  end
end
