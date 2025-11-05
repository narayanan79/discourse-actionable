# frozen_string_literal: true
require "rails_helper"

RSpec.describe ActionableDaily, type: :model do
  fab!(:user)

  describe ".increment_for" do
    it "creates new record when none exists" do
      expect { ActionableDaily.increment_for(user.id) }.to change { ActionableDaily.count }.by(1)

      record = ActionableDaily.find_by(user_id: user.id)
      expect(record.count).to eq(1)
      expect(record.date).to eq(Date.current)
    end

    it "increments existing record for current date" do
      existing = ActionableDaily.create!(user_id: user.id, count: 5, date: Date.current)

      expect { ActionableDaily.increment_for(user.id) }.to change { existing.reload.count }.from(
        5,
      ).to(6)
    end
  end

  describe ".decrement_for" do
    it "decrements existing record" do
      existing = ActionableDaily.create!(user_id: user.id, count: 5, date: Date.current)

      ActionableDaily.decrement_for(user.id)

      expect(existing.reload.count).to eq(4)
    end

    it "does not create record when none exists" do
      expect { ActionableDaily.decrement_for(user.id) }.not_to change { ActionableDaily.count }
    end
  end

  describe "validations" do
    it "requires user_id" do
      record = ActionableDaily.new(count: 1, date: Date.current)
      expect(record).not_to be_valid
      expect(record.errors[:user_id]).to be_present
    end

    it "requires count to be non-negative" do
      record = ActionableDaily.new(user_id: user.id, count: -1, date: Date.current)
      expect(record).not_to be_valid
      expect(record.errors[:count]).to include("must be greater than or equal to 0")
    end
  end
end
