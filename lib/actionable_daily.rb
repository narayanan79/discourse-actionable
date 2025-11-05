# frozen_string_literal: true

class ActionableDaily < ActiveRecord::Base
  self.table_name = 'actionable_daily'

  belongs_to :user

  validates :user_id, presence: true, uniqueness: { scope: :actionable_date }
  validates :actionable_date, presence: true
  validates :actionable_count, presence: true, numericality: { greater_than_or_equal_to: 0 }

  def self.increment_for(user_id)
    date = Date.current
    
    daily_record = find_or_create_by(
      user_id: user_id,
      actionable_date: date
    ) do |record|
      record.actionable_count = 0
    end
    
    daily_record.increment!(:actionable_count)
    daily_record
  rescue ActiveRecord::RecordNotUnique
    # Handle race condition
    retry
  end

  def self.decrement_for(user_id)
    date = Date.current
    
    daily_record = find_by(
      user_id: user_id,
      actionable_date: date
    )
    
    return unless daily_record && daily_record.actionable_count > 0
    
    daily_record.decrement!(:actionable_count)
    daily_record
  end

  def self.count_for(user_id, date = Date.current)
    where(user_id: user_id, actionable_date: date)
      .pluck(:actionable_count)
      .first || 0
  end

  def self.within_daily_limit?(user_id, limit = SiteSetting.actionable_max_per_day)
    count_for(user_id) < limit
  end

  def self.cleanup_old_records(days_to_keep = 30)
    where("actionable_date < ?", days_to_keep.days.ago).delete_all
  end
end