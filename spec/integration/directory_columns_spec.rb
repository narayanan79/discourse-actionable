# frozen_string_literal: true

RSpec.describe "Actionable directory columns" do
  fab!(:giver) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:receiver, :user)
  fab!(:public_post) { Fabricate(:post, user: receiver) }
  fab!(:private_post) { Fabricate(:private_message_post, user: receiver, recipient: giver) }

  let(:columns) { DirectoryColumn.where(name: DiscourseActionable::DirectoryColumns::NAMES) }

  before do
    enable_current_plugin
    [public_post, private_post].each do |post|
      ActionableActionCreator.call(params: { post_id: post.id }, guardian: giver.guardian)
    end
  end

  def all_time_item(user)
    DirectoryItem.find_by(user:, period_type: DirectoryItem.period_types[:all])
  end

  it "counts only actionables on public posts, like core's like columns" do
    DirectoryItem.refresh!

    expect(all_time_item(giver).actionable_given).to eq(1)
    expect(all_time_item(receiver).actionable_received).to eq(1)
  end

  it "hides and shows the columns together with the plugin" do
    DirectoryItem.refresh!
    columns.update_all(enabled: true)

    SiteSetting.actionable_enabled = false
    expect(columns.reload.pluck(:enabled)).to all(eq(false))

    SiteSetting.actionable_enabled = true
    expect(columns.reload.pluck(:enabled)).to all(eq(true))
  end

  it "leaves the admin's column choice alone on refresh" do
    DirectoryItem.refresh!
    columns.update_all(enabled: false)

    DirectoryItem.refresh!

    expect(columns.reload.pluck(:enabled)).to all(eq(false))
  end
end
