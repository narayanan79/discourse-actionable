# frozen_string_literal: true

class AddActionableStatsToUserStats < ActiveRecord::Migration[7.0]
  def change
    add_column :user_stats, :actionable_given, :integer, default: 0, null: false
    add_column :user_stats, :actionable_received, :integer, default: 0, null: false
  end
end
