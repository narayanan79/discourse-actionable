# frozen_string_literal: true

RSpec.describe ActionableActionCreator do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:post_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user) { Fabricate(:user, trust_level: TrustLevel[1]) }
    fab!(:author, :user)
    fab!(:topic) { Fabricate(:topic, user: author) }
    fab!(:post) { Fabricate(:post, topic:, user: author) }

    let(:params) { { post_id: post.id } }
    let(:dependencies) { { guardian: acting_user.guardian } }
    let(:type_id) { DiscourseActionable::POST_ACTION_TYPE_ID }

    before { enable_current_plugin }

    context "when contract is invalid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when post is not found" do
      let(:params) { { post_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:post) }
    end

    context "when the user marks their own post" do
      let(:dependencies) { { guardian: author.guardian } }

      it { is_expected.to fail_a_policy(:can_mark_post_actionable) }
    end

    context "when the user is anonymous" do
      let(:dependencies) { { guardian: Guardian.new } }

      it { is_expected.to fail_a_policy(:can_mark_post_actionable) }
    end

    context "when the user cannot see the post" do
      fab!(:post) { Fabricate(:private_message_post, user: author) }

      it { is_expected.to fail_a_policy(:can_mark_post_actionable) }
    end

    context "when the topic is closed" do
      before { topic.update!(closed: true) }

      it { is_expected.to fail_a_policy(:can_mark_post_actionable) }
    end

    context "when the user is below the minimum trust level" do
      before { SiteSetting.actionable_min_trust_level = 2 }

      it { is_expected.to fail_a_policy(:can_mark_post_actionable) }
    end

    context "when the post author no longer exists" do
      before { post.update_columns(user_id: nil) }

      it { is_expected.to fail_a_policy(:can_mark_post_actionable) }
    end

    context "when the post is already marked by the user" do
      before { described_class.call(params:, **dependencies) }

      it { is_expected.to fail_a_policy(:not_already_actioned) }
    end

    context "when core refuses to create the post action" do
      before { PostActionCreator::CreateResult.any_instance.stubs(:success).returns(false) }

      it { is_expected.to fail_a_step(:create_post_action) }

      it "rolls back the post action core had already saved" do
        expect { result }.not_to change { PostAction.where(post_action_type_id: type_id).count }
      end
    end

    context "when the last write fails" do
      before do
        Post.any_instance.stubs(:update_actionable_count).raises(ActiveRecord::StatementInvalid)
      end

      it "rolls back every earlier write" do
        expect { result }.to raise_error(ActiveRecord::StatementInvalid)

        expect(PostAction.where(post:, post_action_type_id: type_id)).to be_empty
        expect(UserAction.where(target_post_id: post.id)).to be_empty
        expect(acting_user.user_stat.reload.actionable_given).to eq(0)
        expect(author.user_stat.reload.actionable_received).to eq(0)
        expect(ActionableDaily.count_for(acting_user.id)).to eq(0)
      end
    end

    context "when everything is valid" do
      let(:messages) { MessageBus.track_publish("/topic/#{topic.id}") { result } }
      let(:events) { DiscourseEvent.track_events(:actionable_created) { result } }

      it { is_expected.to run_successfully }

      it "creates the post action" do
        expect { result }.to change {
          PostAction.where(post:, user: acting_user, post_action_type_id: type_id).count
        }.by(1)
      end

      it "updates the post's actionable count" do
        expect { result }.to change { post.reload.actionable_count }.from(0).to(1)
      end

      it "logs user actions and stats for the giver and the receiver" do
        result

        rows = UserAction.where(target_post_id: post.id).pluck(:action_type, :user_id)
        expect(rows).to contain_exactly(
          [DiscourseActionable::USER_ACTION_GIVEN, acting_user.id],
          [DiscourseActionable::USER_ACTION_RECEIVED, author.id],
        )
        expect(acting_user.user_stat.reload.actionable_given).to eq(1)
        expect(author.user_stat.reload.actionable_received).to eq(1)
      end

      it "tracks the daily count" do
        expect { result }.to change { ActionableDaily.count_for(acting_user.id) }.by(1)
      end

      it "publishes only the actionable change to the topic channel" do
        expect(messages.size).to eq(1)
        expect(messages.first.data).to include(
          type: :actioned,
          id: post.id,
          actionable_count: 1,
          actioned_by: acting_user.id,
        )
      end

      it "triggers the actionable_created event" do
        expect(events.size).to eq(1)
        expect(events.first[:params].last).to eq(acting_user)
      end

      it "does not publish who marked the post when the site hides it" do
        SiteSetting.actionable_show_who_actioned = false

        expect(messages.first.data).to include(actionable_count: 1)
        expect(messages.first.data).not_to have_key(:actioned_by)
      end
    end

    context "when the post is in a private message the user takes part in" do
      fab!(:post) { Fabricate(:private_message_post, user: author, recipient: acting_user) }

      it "does not count the action in user stats" do
        expect(result).to run_successfully
        expect(acting_user.user_stat.reload.actionable_given).to eq(0)
        expect(author.user_stat.reload.actionable_received).to eq(0)
      end
    end
  end
end
