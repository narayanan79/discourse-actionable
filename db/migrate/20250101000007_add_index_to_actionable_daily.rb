# frozen_string_literal: true

class AddIndexToActionableDaily < ActiveRecord::Migration[7.0]
  def change
    # Add composite index on user_id and actionable_date for fast lookups
    # This index supports the common query pattern: WHERE user_id = X AND actionable_date = Y
    add_index :actionable_daily,
              %i[user_id actionable_date],
              unique: true,
              name: "index_actionable_daily_on_user_and_date"
  end
end
