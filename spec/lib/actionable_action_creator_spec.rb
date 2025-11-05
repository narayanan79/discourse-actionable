# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActionableActionCreator do
  fab!(:user) { Fabricate(:user, trust_level: 1) }
  fab!(:admin)
  fab!(:post)
  fab!(:user_post) { Fabricate(:post, user: user) }
  fab!(:guardian) { Guardian.new(user) }

  before do
    SiteSetting.actionable_enabled = true
    SiteSetting.actionable_min_trust_level = 0
    SiteSetting.actionable_max_per_day = 50
  end

  describe ".call" do
    it "creates actionable action successfully" do
      result = described_class.call(post_id: post.id, user: user, guardian: guardian)

      expect(result).to be_success
      expect(result.post).to eq(post)
      expect(
        PostAction.exists?(
          post: post,
          user: user,
          post_action_type_id: PostActionType.types[:actionable],
        ),
      ).to be true
    end

    it "updates post actionable count" do
      expect { described_class.call(post_id: post.id, user: user, guardian: guardian) }.to change {
        post.reload.actionable_count
      }.from(0).to(1)
    end

    it "tracks daily actionable count" do
      expect { described_class.call(post_id: post.id, user: user, guardian: guardian) }.to change {
        ActionableDaily.count_for(user.id)
      }.by(1)
    end

    it "fails when post not found" do
      result = described_class.call(post_id: 999_999, user: user, guardian: guardian)

      expect(result).to be_failure
      expect(result.model).to be_nil
    end

    it "fails when user tries to action own post" do
      result = described_class.call(post_id: user_post.id, user: user, guardian: Guardian.new(user))

      expect(result).to be_failure
    end

    it "fails when actionable is disabled" do
      SiteSetting.actionable_enabled = false

      result = described_class.call(post_id: post.id, user: user, guardian: guardian)

      expect(result).to be_failure
    end

    it "fails when user below trust level requirement" do
      SiteSetting.actionable_min_trust_level = 2

      result = described_class.call(post_id: post.id, user: user, guardian: guardian)

      expect(result).to be_failure
    end

    it "fails when post is trashed" do
      post.trash!

      result = described_class.call(post_id: post.id, user: user, guardian: guardian)

      expect(result).to be_failure
    end

    it "fails when topic is archived" do
      post.topic.update!(archived: true)

      result = described_class.call(post_id: post.id, user: user, guardian: guardian)

      expect(result).to be_failure
    end

    it "fails when already actioned" do
      PostAction.act(user, post, PostActionType.types[:actionable])

      result = described_class.call(post_id: post.id, user: user, guardian: guardian)

      expect(result).to be_failure
    end

    it "respects rate limiting" do
      SiteSetting.actionable_max_per_day = 1

      # First action should succeed
      result1 = described_class.call(post_id: post.id, user: user, guardian: guardian)
      expect(result1).to be_success

      # Second action should fail due to rate limit
      post2 = Fabricate(:post)
      result2 = described_class.call(post_id: post2.id, user: user, guardian: Guardian.new(user))
      expect(result2).to be_failure
    end

    it "triggers discourse events" do
      events = []
      # rubocop:disable Discourse/Plugins/UsePluginInstanceOn
      DiscourseEvent.on(:actionable_created) do |post_action, creator|
        events << { post_action: post_action, creator: creator }
      end
      # rubocop:enable Discourse/Plugins/UsePluginInstanceOn

      described_class.call(post_id: post.id, user: user, guardian: guardian)

      expect(events.length).to eq(1)
      expect(events.first[:creator]).to eq(user)
    end

    it "publishes real-time updates" do
      allow(post).to receive(:publish_change_to_clients!)

      described_class.call(post_id: post.id, user: user, guardian: guardian)

      expect(post).to have_received(:publish_change_to_clients!).with(
        :actioned,
        hash_including(actionable_count: 1, user_id: user.id),
      )
    end
  end
end
