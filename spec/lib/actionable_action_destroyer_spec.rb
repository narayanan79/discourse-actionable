# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActionableActionDestroyer do
  fab!(:user)
  fab!(:post)
  fab!(:guardian) { Guardian.new(user) }

  let!(:post_action) { PostAction.act(user, post, PostActionType.types[:actionable]) }

  before do
    SiteSetting.actionable_enabled = true
    post.update_actionable_count
  end

  describe ".call" do
    it "destroys actionable action successfully" do
      result = described_class.call(post_id: post.id, user: user, guardian: guardian)

      expect(result).to be_success
      expect(result.post).to eq(post)
      expect(post_action.reload.deleted_at).not_to be_nil
    end

    it "updates post actionable count" do
      expect(post.actionable_count).to eq(1)

      result = described_class.call(post_id: post.id, user: user, guardian: guardian)

      expect(result).to be_success
      expect(post.reload.actionable_count).to eq(0)
    end

    it "decrements daily actionable count" do
      # Ensure there's a daily record
      ActionableDaily.increment_for(user.id)
      initial_count = ActionableDaily.count_for(user.id)

      described_class.call(post_id: post.id, user: user, guardian: guardian)

      expect(ActionableDaily.count_for(user.id)).to eq(initial_count - 1)
    end

    it "fails when post not found" do
      result = described_class.call(post_id: 999_999, user: user, guardian: guardian)

      expect(result).to be_failure
      expect(result.model).to be_nil
    end

    it "fails when post action not found" do
      post_action.remove_act!(user)

      result = described_class.call(post_id: post.id, user: user, guardian: guardian)

      expect(result).to be_failure
    end

    it "fails when user cannot delete action" do
      other_user = Fabricate(:user)
      other_guardian = Guardian.new(other_user)

      result = described_class.call(post_id: post.id, user: other_user, guardian: other_guardian)

      expect(result).to be_failure
    end

    it "fails when action already deleted" do
      post_action.remove_act!(user)

      result = described_class.call(post_id: post.id, user: user, guardian: guardian)

      expect(result).to be_failure
    end

    it "triggers discourse events" do
      events = []
      # rubocop:disable Discourse/Plugins/UsePluginInstanceOn
      DiscourseEvent.on(:actionable_destroyed) do |post_action, destroyer|
        events << { post_action: post_action, destroyer: destroyer }
      end
      # rubocop:enable Discourse/Plugins/UsePluginInstanceOn

      described_class.call(post_id: post.id, user: user, guardian: guardian)

      expect(events.length).to eq(1)
      expect(events.first[:destroyer]).to eq(user)
    end

    it "publishes real-time updates" do
      allow(post).to receive(:publish_change_to_clients!)

      described_class.call(post_id: post.id, user: user, guardian: guardian)

      expect(post).to have_received(:publish_change_to_clients!).with(
        :unactioned,
        hash_including(actionable_count: 0, user_id: user.id),
      )
    end

    it "logs staff actions for staff members" do
      staff_user = Fabricate(:admin)
      staff_action = PostAction.act(staff_user, post, PostActionType.types[:actionable])
      post.update_actionable_count

      expect_any_instance_of(StaffActionLogger).to receive(:log_post_action)

      described_class.call(post_id: post.id, user: staff_user, guardian: Guardian.new(staff_user))
    end

    it "handles errors gracefully" do
      allow_any_instance_of(PostAction).to receive(:remove_act!).and_raise(
        StandardError,
        "Database error",
      )

      result = described_class.call(post_id: post.id, user: user, guardian: guardian)

      expect(result).to be_failure
    end
  end
end
