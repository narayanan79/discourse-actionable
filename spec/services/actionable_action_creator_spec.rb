# frozen_string_literal: true
require "rails_helper"

RSpec.describe ActionableActionCreator, type: :service do
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
    context "when user is authenticated" do
      it "creates an actionable action successfully" do
        result = ActionableActionCreator.call(guardian: guardian, post: post)

        expect(result).to be_success
        expect(result.post_action).to be_present
        expect(result.post_action.user).to eq(user)
        expect(result.post_action.post).to eq(post)
        expect(result.post_action.post_action_type.name_key).to eq("actionable")
      end

      it "increments ActionableDaily counter" do
        expect { ActionableActionCreator.call(guardian: guardian, post: post) }.to change {
          ActionableDaily.where(user_id: user.id).count
        }.by(1)
      end

      it "publishes MessageBus update" do
        messages =
          MessageBus.track_publish("/topic/#{post.topic.id}") do
            ActionableActionCreator.call(guardian: guardian, post: post)
          end

        expect(messages.length).to eq(1)
        message = messages.first
        expect(message.data[:type]).to eq("actioned")
        expect(message.data[:id]).to eq(post.id)
        expect(message.data[:actioned_by]).to eq(user.id)
        expect(message.data[:actionable_count]).to eq(1)
      end
    end

    context "when user already actioned the post" do
      before { ActionableActionCreator.call(guardian: guardian, post: post) }

      it "fails to create duplicate action" do
        result = ActionableActionCreator.call(guardian: guardian, post: post)

        expect(result).to be_failure
      end
    end

    context "when actionable is disabled" do
      before { SiteSetting.actionable_enabled = false }

      it "fails to create action" do
        result = ActionableActionCreator.call(guardian: guardian, post: post)

        expect(result).to be_failure
      end
    end

    context "when user is anonymous" do
      let(:anonymous_guardian) { Guardian.new(nil) }

      it "fails to create action" do
        result = ActionableActionCreator.call(guardian: anonymous_guardian, post: post)

        expect(result).to be_failure
      end
    end

    context "when user cannot see the post" do
      let(:private_post) { Fabricate(:private_message_post) }

      it "fails to create action" do
        result = ActionableActionCreator.call(guardian: guardian, post: private_post)

        expect(result).to be_failure
      end
    end
  end
end
