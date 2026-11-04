# frozen_string_literal: true

RSpec.describe ActionableDaily do
  fab!(:user)

  describe ".increment_for" do
    it "creates the day's row once and increments it afterwards" do
      2.times { described_class.increment_for(user.id) }

      expect(described_class.where(user_id: user.id).count).to eq(1)
      expect(described_class.count_for(user.id)).to eq(2)
    end
  end

  describe ".decrement_for" do
    it "decrements the given day and never goes below zero" do
      day = 2.days.ago.to_date
      described_class.increment_for(user.id, day)

      2.times { described_class.decrement_for(user.id, day) }

      expect(described_class.count_for(user.id, day)).to eq(0)
    end

    it "does not create a row" do
      expect { described_class.decrement_for(user.id) }.not_to change { described_class.count }
    end
  end

  describe ".cleanup_old_records" do
    it "keeps only the retention period" do
      described_class.increment_for(user.id, 100.days.ago.to_date)
      described_class.increment_for(user.id, Date.current)

      described_class.cleanup_old_records

      expect(described_class.pluck(:actionable_date)).to contain_exactly(Date.current)
    end
  end
end
