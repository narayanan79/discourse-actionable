# frozen_string_literal: true

class AddActionableColumnsToDirectoryItems < ActiveRecord::Migration[7.1]
  def up
    add_column :directory_items, :actionable_received, :integer, null: false, default: 0
    add_column :directory_items, :actionable_given, :integer, null: false, default: 0

    # Add indexes for sorting by actionable columns
    add_index :directory_items, :actionable_received
    add_index :directory_items, :actionable_given
  end

  def down
    remove_column :directory_items, :actionable_received
    remove_column :directory_items, :actionable_given
  end
end
