# frozen_string_literal: true

class AddActionableCountToPosts < ActiveRecord::Migration[7.0]
  def up
    add_column :posts, :actionable_count, :integer, default: 0, null: false
    add_index :posts, :actionable_count, name: "index_posts_on_actionable_count"

    # Only posts that already have actionable post actions need a value; all
    # other rows keep the column default. An earlier version first copied a
    # legacy `actionable_count` post custom field (overwritten by this statement
    # anyway); that step failed on non-numeric values and rewrote every post.
    execute <<~SQL
      UPDATE posts p
      SET actionable_count = x.total
      FROM (
        SELECT post_id, COUNT(*) AS total
        FROM post_actions
        WHERE post_action_type_id = 50 AND deleted_at IS NULL
        GROUP BY post_id
      ) x
      WHERE p.id = x.post_id
    SQL
  end

  def down
    remove_index :posts, name: "index_posts_on_actionable_count"
    remove_column :posts, :actionable_count
  end
end
