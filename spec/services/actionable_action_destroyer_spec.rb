# frozen_string_literal: true
require "rails_helper"

RSpec.describe ActionableActionDestroyer, type: :service do
  let(:user) { Fabricate(:user) }
  let(:admin) { Fabricate(:admin) }
  let(:post) { Fabricate(:post) }
  let(:guardian) { Guardian.new(user) }
  let(:admin_guardian) { Guardian.new(admin) }

  before do
    SiteSetting.actionable_enabled = true
    # Ensure actionable post action type exists
    PostActionType.find_or_create_by!(name_key: "actionable") do |pat|
      pat.is_flag = false
      pat.icon = "check"
      pat.position = 50
    end
  end

  describe "#call" do
    context "when user has actioned the post" do
      let!(:post_action) do
        ActionableActionCreator.call(guardian: guardian, post: post).post_action
      end

      it "destroys the actionable action successfully" do
        result = ActionableActionDestroyer.call(guardian: guardian, post: post)

        expect(result).to be_success
        expect(result.post_action).to be_present
        expect(result.post_action.deleted_at).to be_present
        expect(result.post_action.user).to eq(user)
        expect(result.post_action.post).to eq(post)
      end

      it "decrements ActionableDaily counter" do
        expect { ActionableActionDestroyer.call(guardian: guardian, post: post) }.to change {
          ActionableDaily.where(user_id: user.id).first&.count
        }.by(-1)
      end

      it "publishes MessageBus update" do
        messages =
          MessageBus.track_publish("/topic/#{post.topic.id}") do
            ActionableActionDestroyer.call(guardian: guardian, post: post)
          end

        expect(messages.length).to eq(1)
        message = messages.first
        expect(message.data[:type]).to eq("unactioned")
        expect(message.data[:id]).to eq(post.id)
        expect(message.data[:actioned_by]).to eq(user.id)
        expect(message.data[:actionable_count]).to eq(0)
      end

      it "allows destruction at any time (no timeout, like Like)" do
        post_action.update!(created_at: 1.year.ago)
        result = ActionableActionDestroyer.call(guardian: guardian, post: post)
        expect(result).to be_success
      end
    end

    context "when user has not actioned the post" do
      it "fails to destroy non-existent action" do
        result = ActionableActionDestroyer.call(guardian: guardian, post: post)

        expect(result).to be_failure
      end
    end

    context 'when trying to destroy another user\'s action' do
      let(:other_user) { Fabricate(:user) }
      let(:other_guardian) { Guardian.new(other_user) }

      before { ActionableActionCreator.call(guardian: other_guardian, post: post) }

      it "fails to destroy action by different user" do
        result = ActionableActionDestroyer.call(guardian: guardian, post: post)

        expect(result).to be_failure
      end
    end

    context "when actionable is disabled" do
      let!(:post_action) do
        ActionableActionCreator.call(guardian: guardian, post: post).post_action
      end

      before { SiteSetting.actionable_enabled = false }

      it "fails to destroy action" do
        result = ActionableActionDestroyer.call(guardian: guardian, post: post)

        expect(result).to be_failure
      end
    end

    context "when user is anonymous" do
      let(:anonymous_guardian) { Guardian.new(nil) }

      it "fails to destroy action" do
        result = ActionableActionDestroyer.call(guardian: anonymous_guardian, post: post)

        expect(result).to be_failure
      end
    end

    context "when admin destroys user action" do
      let!(:post_action) do
        ActionableActionCreator.call(guardian: guardian, post: post).post_action
      end

      it "allows admin to destroy any actionable action" do
        result = ActionableActionDestroyer.call(guardian: admin_guardian, post: post)

        expect(result).to be_success
        expect(result.post_action.deleted_at).to be_present
      end

      it "publishes correct MessageBus update with original user id" do
        messages =
          MessageBus.track_publish("/topic/#{post.topic.id}") do
            ActionableActionDestroyer.call(guardian: admin_guardian, post: post)
          end

        expect(messages.length).to eq(1)
        message = messages.first
        expect(message.data[:actioned_by]).to eq(user.id) # Original user, not admin
      end
    end

    context "when post action is already deleted" do
      let!(:post_action) do
        action = ActionableActionCreator.call(guardian: guardian, post: post).post_action
        action.update!(deleted_at: Time.current)
        action
      end

      it "fails to destroy already deleted action" do
        result = ActionableActionDestroyer.call(guardian: guardian, post: post)

        expect(result).to be_failure
      end
    end
  end
end
