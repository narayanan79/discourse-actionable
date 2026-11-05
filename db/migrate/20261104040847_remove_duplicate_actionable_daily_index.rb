# frozen_string_literal: true

# 20250101000007 added a unique index identical to the one created with the
# table (index_actionable_daily_on_user_id_and_date). Keep the original.
class RemoveDuplicateActionableDailyIndex < ActiveRecord::Migration[7.1]
  def up
    execute "DROP INDEX IF EXISTS index_actionable_daily_on_user_and_date"
  end

  def down
    execute <<~SQL
      CREATE UNIQUE INDEX IF NOT EXISTS index_actionable_daily_on_user_and_date
      ON actionable_daily (user_id, actionable_date)
    SQL
  end
end
