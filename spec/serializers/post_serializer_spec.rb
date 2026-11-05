# frozen_string_literal: true

RSpec.describe PostSerializer do
  fab!(:viewer) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:author, :user)
  fab!(:topic) { Fabricate(:topic, user: author) }
  fab!(:target_post) { Fabricate(:post, topic:, user: author) }

  before { enable_current_plugin }

  def serialize(post, user = viewer)
    described_class.new(post.reload, scope: user.guardian, root: false).as_json
  end

  def mark(post, user = viewer)
    ActionableActionCreator.call(params: { post_id: post.id }, guardian: user.guardian)
  end

  it "describes a post the viewer can mark" do
    expect(serialize(target_post)).to include(
      show_actionable: true,
      actionable_count: 0,
      actioned: false,
      can_undo_actionable: false,
      can_toggle_actionable: true,
    )
  end

  it "describes a post the viewer has marked" do
    mark(target_post)

    expect(serialize(target_post)).to include(
      actionable_count: 1,
      actioned: true,
      can_undo_actionable: true,
      can_toggle_actionable: true,
    )
  end

  it "stops offering undo once the undo window has passed" do
    mark(target_post)
    PostAction.where(post: target_post, user: viewer).update_all(created_at: 1.day.ago)

    expect(serialize(target_post)).to include(
      actioned: true,
      can_undo_actionable: false,
      can_toggle_actionable: false,
    )
  end

  it "disables the button where the server would refuse the mark" do
    topic.update!(closed: true)
    expect(serialize(target_post)[:can_toggle_actionable]).to eq(false)

    topic.update!(closed: false)
    expect(serialize(target_post, author)[:can_toggle_actionable]).to eq(false)
  end

  it "does not add attributes when the plugin is disabled" do
    SiteSetting.actionable_enabled = false

    expect(serialize(target_post).keys).not_to include(:show_actionable, :actionable_count)
  end

  describe "query count" do
    # Shape of the per-post fallback lookup (PostAction.find_by ... LIMIT).
    let(:lookup) { /FROM "post_actions" WHERE .*"post_action_type_id" = .*LIMIT/ }

    before do
      Fabricate.times(2, :post, topic:, user: author)
      mark(target_post)
    end

    it "looks the action up when serializing a single post" do
      queries = track_sql_queries { serialize(target_post) }

      expect(queries.grep(lookup)).not_to be_empty
    end

    it "reuses the topic view's preloaded post actions instead" do
      topic_view = TopicView.new(topic.id, viewer)
      serializer = TopicViewSerializer.new(topic_view, scope: viewer.guardian, root: false)

      queries = track_sql_queries { serializer.as_json }

      expect(queries.grep(lookup)).to be_empty
    end
  end
end
