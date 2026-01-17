# frozen_string_literal: true

class ActionableDaily < ActiveRecord::Base
  self.table_name = "actionable_daily"

  belongs_to :user

  validates :user_id, presence: true, uniqueness: { scope: :actionable_date }
  validates :actionable_date, presence: true
  validates :actionable_count, presence: true, numericality: { greater_than_or_equal_to: 0 }

  def self.increment_for(user_id)
    date = Date.current

    # Use atomic SQL update to prevent race conditions
    result =
      where(user_id: user_id, actionable_date: date).update_all(
        "actionable_count = actionable_count + 1",
      )

    # If no record was updated, create one
    if result == 0
      begin
        create!(user_id: user_id, actionable_date: date, actionable_count: 1)
      rescue ActiveRecord::RecordNotUnique
        # Another thread created it, retry the update
        retry
      end
    end

    # Return the record (optional, for backward compatibility)
    find_by(user_id: user_id, actionable_date: date)
  end

  def self.decrement_for(user_id)
    date = Date.current

    # Use atomic SQL update with condition to prevent negative counts
    where(user_id: user_id, actionable_date: date).where("actionable_count > 0").update_all(
      "actionable_count = actionable_count - 1",
    )

    # Return the record (optional, for backward compatibility)
    find_by(user_id: user_id, actionable_date: date)
  end

  def self.count_for(user_id, date = Date.current)
    where(user_id: user_id, actionable_date: date).pluck(:actionable_count).first || 0
  end

  def self.within_daily_limit?(user_id, limit = SiteSetting.actionable_max_per_day)
    count_for(user_id) < limit
  end

  def self.cleanup_old_records(days_to_keep = 30)
    where("actionable_date < ?", days_to_keep.days.ago).delete_all
  end
end
