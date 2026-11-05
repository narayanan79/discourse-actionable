# frozen_string_literal: true

RSpec.describe UsersController do
  fab!(:giver) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:receiver, :user)
  fab!(:target_post) { Fabricate(:post, user: receiver) }

  before { enable_current_plugin }

  describe "#summary" do
    def summary_for(user)
      get "/u/#{user.username}/summary.json"
      expect(response.status).to eq(200)
      response.parsed_body["user_summary"]
    end

    def mark_target_post
      ActionableActionCreator.call(params: { post_id: target_post.id }, guardian: giver.guardian)
    end

    it "shows up-to-date stats to the user right after a post is marked" do
      sign_in(receiver)
      expect(summary_for(receiver)["actionable_received"]).to eq(0)

      mark_target_post

      expect(summary_for(receiver)["actionable_received"]).to eq(1)
    end

    it "shows up-to-date stats to anonymous visitors right after a post is marked" do
      # Core hides the profiles of new users without posts from anonymous
      # visitors (404), and the giver has no posts.
      SiteSetting.hide_new_user_profiles = false
      expect(summary_for(giver)["actionable_given"]).to eq(0)

      mark_target_post

      expect(summary_for(giver)["actionable_given"]).to eq(1)
    end

    it "shows up-to-date stats to every other signed-in viewer right after a post is marked" do
      SiteSetting.hide_new_user_profiles = false
      sign_in(Fabricate(:user))
      expect(summary_for(receiver)["actionable_received"]).to eq(0)

      # The summary is cached per viewer: a change that bypasses the plugin
      # does not show yet.
      receiver.user_stat.update!(actionable_received: 5)
      expect(summary_for(receiver)["actionable_received"]).to eq(0)

      mark_target_post

      expect(summary_for(receiver)["actionable_received"]).to eq(6)
    end

    it "lists who marked the user's posts using core's user serializer" do
      SiteSetting.enable_names = false
      mark_target_post
      sign_in(receiver)

      entry = summary_for(receiver)["most_actionabled_by_users"].sole

      expect(entry).to include("id" => giver.id, "username" => giver.username, "count" => 1)
      expect(entry).not_to have_key("name")
    end

    it "lists whose posts the user marked" do
      mark_target_post
      sign_in(giver)

      entry = summary_for(giver)["most_actionabled_users"].sole

      expect(entry).to include("id" => receiver.id, "count" => 1)
    end

    it "omits the lists when there is nothing to show" do
      sign_in(receiver)

      summary = summary_for(receiver)

      expect(summary).not_to have_key("most_actionabled_by_users")
      expect(summary).not_to have_key("most_actionabled_users")
    end
  end
end
