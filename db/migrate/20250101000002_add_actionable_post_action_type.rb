# frozen_string_literal: true

class AddActionablePostActionType < ActiveRecord::Migration[7.0]
  # Plain SQL so the migration does not depend on application models.
  # db/fixtures/001_actionable_post_action_type.rb keeps the row up to date.
  def up
    execute <<~SQL
      INSERT INTO post_action_types (id, name_key, is_flag, icon, position, created_at, updated_at)
      SELECT 50, 'actionable', FALSE, 'bullseye', 3, NOW(), NOW()
      WHERE NOT EXISTS (
        SELECT 1 FROM post_action_types WHERE id = 50 OR name_key = 'actionable'
      )
    SQL
  end

  def down
    execute "DELETE FROM post_action_types WHERE name_key = 'actionable'"
  end
end
