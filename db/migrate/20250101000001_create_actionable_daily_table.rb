# frozen_string_literal: true

class CreateActionableDailyTable < ActiveRecord::Migration[7.0]
  def up
    create_table :actionable_daily do |t|
      t.references :user, null: false, foreign_key: true
      t.date :actionable_date, null: false
      t.integer :actionable_count, default: 0, null: false
      t.timestamps
    end

    add_index :actionable_daily, [:user_id, :actionable_date], unique: true, name: 'index_actionable_daily_on_user_id_and_date'
    add_index :actionable_daily, :actionable_date, name: 'index_actionable_daily_on_date'
  end

  def down
    drop_table :actionable_daily
  end
end