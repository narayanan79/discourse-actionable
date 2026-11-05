# frozen_string_literal: true

RSpec.describe "Actionable button" do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:author, :user)
  fab!(:topic) { Fabricate(:topic, user: author) }
  fab!(:target_post) { Fabricate(:post, topic:, user: author) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:button) { "#post_1 .post-action-menu__actionable" }
  let(:count) { "#post_1 .post-action-menu__actionable-count" }

  before { enable_current_plugin }

  def computed_color(selector)
    page.evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json})).color")
  end

  # The colour a theme variable resolves to, as the browser computes it.
  def theme_color(variable)
    page.evaluate_script(<<~JS)
      (() => {
        const probe = document.createElement("span");
        probe.style.color = "var(#{variable})";
        document.body.append(probe);
        const color = getComputedStyle(probe).color;
        probe.remove();
        return color;
      })()
    JS
  end

  it "lets a user mark and unmark a post" do
    sign_in(user)
    topic_page.visit_topic(topic)

    find(button).click

    expect(page).to have_css("#{button}.has-actionable")
    expect(page).to have_css(count, text: "1")
    expect(target_post.reload.actionable_count).to eq(1)

    find(button).click

    expect(page).to have_css("#{button}.actionable")
    expect(page).to have_no_css(count)
    expect(target_post.reload.actionable_count).to eq(0)
  end

  it "colours the icon of a marked post with the theme's tertiary colour" do
    sign_in(user)
    topic_page.visit_topic(topic)
    find(button).click

    icon = "#{button}.has-actionable.actionable-by-me .d-icon"
    expect(page).to have_css(icon)

    expected = theme_color("--tertiary")
    # discourse-insightful uses --gold; the check only means something if they differ.
    expect(expected).not_to eq(theme_color("--gold"))
    try_until_success { expect(computed_color(icon)).to eq(expected) }
  end

  it "shows who marked a post" do
    ActionableActionCreator.call(params: { post_id: target_post.id }, guardian: user.guardian)
    sign_in(Fabricate(:user))
    topic_page.visit_topic(topic)

    find(count).click

    expect(page).to have_css("#post_1 .who-actioned.--expanded [data-user-card='#{user.username}']")
  end

  it "updates the count when someone else marks the post" do
    sign_in(Fabricate(:user))
    topic_page.visit_topic(topic)
    expect(page).to have_css(button)

    ActionableActionCreator.call(params: { post_id: target_post.id }, guardian: user.guardian)

    expect(page).to have_css(count, text: "1")
  end

  it "sends anonymous visitors to the login page" do
    topic_page.visit_topic(topic)

    find(button).click

    expect(page).to have_current_path("/login")
  end
end
