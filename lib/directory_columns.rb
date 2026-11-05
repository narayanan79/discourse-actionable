# frozen_string_literal: true

module DiscourseActionable
  # User directory columns ("Actionable Given" / "Actionable Received").
  #
  # Counting rules match core's like columns (DirectoryItem /
  # UserStat::COUNTABLE_POST_CONDITIONS): only actions on visible, non-deleted,
  # regular posts in public, non-deleted, visible topics are counted.
  module DirectoryColumns
    GIVEN = "actionable_given"
    RECEIVED = "actionable_received"
    NAMES = [GIVEN, RECEIVED].freeze

    # The MATERIALIZED CTE makes PostgreSQL read only this action type through
    # an (action_type, ...) index first, so the cost follows actionable activity
    # rather than the size of user_actions. Unchanged rows are not rewritten.
    def self.query(column:, action_type:)
      raise ArgumentError, "unknown column #{column}" if NAMES.exclude?(column)

      <<~SQL
        WITH actionable_actions AS MATERIALIZED (
          SELECT ua.user_id, ua.target_post_id
          FROM user_actions ua
          WHERE ua.action_type = #{action_type.to_i}
            AND ua.created_at > :since
        ),
        actionable_counts AS (
          SELECT aa.user_id, COUNT(*) AS total
          FROM actionable_actions aa
          JOIN posts p ON p.id = aa.target_post_id
          JOIN topics t ON t.id = p.topic_id
          WHERE p.deleted_at IS NULL
            AND p.post_type = :regular_post_type
            AND NOT p.hidden
            AND t.deleted_at IS NULL
            AND t.visible
            AND t.archetype = 'regular'
          GROUP BY aa.user_id
        )
        UPDATE directory_items di
        SET #{column} = COALESCE(ac.total, 0)
        FROM directory_items d
        LEFT JOIN actionable_counts ac ON ac.user_id = d.user_id
        WHERE di.id = d.id
          AND d.period_type = :period_type
          AND d.#{column} <> COALESCE(ac.total, 0)
      SQL
    end

    # Core creates plugin columns disabled. Admins choose which ones to show;
    # this only hides/shows them together with the plugin itself.
    def self.set_enabled(enabled)
      DirectoryColumn.where(name: NAMES).update_all(enabled: !!enabled)
    end
  end
end
