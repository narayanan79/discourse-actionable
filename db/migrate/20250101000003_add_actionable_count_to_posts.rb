# frozen_string_literal: true

class AddActionableCountToPosts < ActiveRecord::Migration[7.0]
  def up
    # Add actionable_count column to posts table for performance
    add_column :posts, :actionable_count, :integer, default: 0, null: false
    add_index :posts, :actionable_count, name: 'index_posts_on_actionable_count'

    # Migrate existing data from custom fields
    execute <<~SQL
      UPDATE posts 
      SET actionable_count = COALESCE(
        (SELECT value::integer 
         FROM post_custom_fields 
         WHERE post_custom_fields.post_id = posts.id 
         AND post_custom_fields.name = 'actionable_count'
         LIMIT 1), 
        0
      )
    SQL

    # Update actionable_count based on actual post_actions
    execute <<~SQL
      UPDATE posts 
      SET actionable_count = (
        SELECT COUNT(*) 
        FROM post_actions 
        WHERE post_actions.post_id = posts.id 
        AND post_actions.post_action_type_id = 50
        AND post_actions.deleted_at IS NULL
      )
    SQL
  end

  def down
    remove_index :posts, name: 'index_posts_on_actionable_count'
    remove_column :posts, :actionable_count
  end
end