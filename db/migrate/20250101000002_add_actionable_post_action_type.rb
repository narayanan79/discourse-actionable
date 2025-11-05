# frozen_string_literal: true

class AddActionablePostActionType < ActiveRecord::Migration[7.0]
  def up
    # Add actionable post action type if it doesn't exist
    unless PostActionType.where(name_key: 'actionable').exists?
      PostActionType.create!(
        id: 50,
        name_key: 'actionable',
        is_flag: false,
        icon: 'check',
        position: 3
      )
    end
  end

  def down
    PostActionType.where(name_key: 'actionable').delete_all
  end
end