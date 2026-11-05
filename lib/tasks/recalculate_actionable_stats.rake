# frozen_string_literal: true

desc "Recalculate actionable counters (user_stats and posts.actionable_count) from source data"
task "actionable:recalculate_stats" => :environment do
  args = {
    type_id: DiscourseActionable::POST_ACTION_TYPE_ID,
    given: DiscourseActionable::USER_ACTION_GIVEN,
    received: DiscourseActionable::USER_ACTION_RECEIVED,
  }

  # Same rule as UserAction.log_action!: private messages are not counted.
  stats_updated = DB.exec(<<~SQL, args)
    UPDATE user_stats us
    SET actionable_given = COALESCE(x.given, 0),
        actionable_received = COALESCE(x.received, 0)
    FROM user_stats s
    LEFT JOIN (
      SELECT ua.user_id,
             COUNT(*) FILTER (WHERE ua.action_type = :given) AS given,
             COUNT(*) FILTER (WHERE ua.action_type = :received) AS received
      FROM user_actions ua
      JOIN topics t ON t.id = ua.target_topic_id
      WHERE ua.action_type IN (:given, :received)
        AND t.archetype <> 'private_message'
      GROUP BY ua.user_id
    ) x ON x.user_id = s.user_id
    WHERE us.user_id = s.user_id
      AND (
        s.actionable_given <> COALESCE(x.given, 0)
        OR s.actionable_received <> COALESCE(x.received, 0)
      )
  SQL

  posts_updated = DB.exec(<<~SQL, args)
    UPDATE posts p
    SET actionable_count = x.total
    FROM (
      SELECT post_id, COUNT(*) AS total
      FROM post_actions
      WHERE post_action_type_id = :type_id AND deleted_at IS NULL
      GROUP BY post_id
    ) x
    WHERE p.id = x.post_id AND p.actionable_count <> x.total
  SQL

  posts_reset = DB.exec(<<~SQL, args)
    UPDATE posts p
    SET actionable_count = 0
    WHERE p.actionable_count > 0
      AND NOT EXISTS (
        SELECT 1 FROM post_actions pa
        WHERE pa.post_id = p.id
          AND pa.post_action_type_id = :type_id
          AND pa.deleted_at IS NULL
      )
  SQL

  puts "user_stats rows corrected: #{stats_updated}"
  puts "posts.actionable_count corrected: #{posts_updated + posts_reset}"
end
