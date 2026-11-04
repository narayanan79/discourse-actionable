# frozen_string_literal: true

# Core's generic endpoint must not be a way around the plugin's rules.
RSpec.describe PostActionsController do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:own_post) { Fabricate(:post, user:) }
  fab!(:other_post, :post)

  let(:actionable_id) { DiscourseActionable::POST_ACTION_TYPE_ID }
  let(:like_id) { PostActionType::LIKE_POST_ACTION_ID }

  before do
    enable_current_plugin
    sign_in(user)
  end

  it "refuses to create actionable post actions" do
    post "/post_actions.json", params: { id: own_post.id, post_action_type_id: actionable_id }

    expect(response.status).to eq(403)
    expect(PostAction.where(post: own_post)).to be_empty
  end

  it "refuses even when the plugin is disabled" do
    SiteSetting.actionable_enabled = false

    post "/post_actions.json", params: { id: other_post.id, post_action_type_id: actionable_id }

    expect(response.status).to eq(403)
  end

  it "still accepts other post action types" do
    post "/post_actions.json", params: { id: other_post.id, post_action_type_id: like_id }

    expect(response.status).to eq(200)
  end
end

RSpec.describe PostActionUsersController do
  fab!(:actor) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:target_post, :post)

  before do
    enable_current_plugin
    ActionableActionCreator.call(params: { post_id: target_post.id }, guardian: actor.guardian)
  end

  it "does not list who marked a post as actionable" do
    params = { id: target_post.id, post_action_type_id: DiscourseActionable::POST_ACTION_TYPE_ID }

    get "/post_action_users.json", params: params

    expect(response.status).to eq(403)
  end

  it "still lists other post action types" do
    params = { id: target_post.id, post_action_type_id: PostActionType::LIKE_POST_ACTION_ID }

    get "/post_action_users.json", params: params

    expect(response.status).to eq(200)
  end
end
