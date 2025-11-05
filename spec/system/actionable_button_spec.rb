# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Actionable button", type: :system do
  fab!(:user) { Fabricate(:user, trust_level: 1) }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }

  before do
    SiteSetting.actionable_enabled = true
    SiteSetting.actionable_min_trust_level = 0
    SiteSetting.actionable_show_who_actioned = true
    sign_in(user)
  end

  it "displays actionable button on posts" do
    visit "/t/#{topic.slug}/#{topic.id}"

    within(".post-controls") do
      expect(page).to have_css(".toggle-actionable")
      expect(page).to have_css(".d-icon-far-check-square")
    end
  end

  it "allows user to mark post as actionable" do
    visit "/t/#{topic.slug}/#{topic.id}"

    within(".post-controls") do
      find(".toggle-actionable").click

      # Should show animation and change to actioned state
      expect(page).to have_css(".has-actionable")
      expect(page).to have_css(".d-icon-check-square")
      expect(page).to have_content("1") # Count should show
    end

    # Verify database changes
    expect(
      PostAction.exists?(
        post: post,
        user: user,
        post_action_type_id: PostActionType.types[:actionable],
      ),
    ).to be true
  end

  it "allows user to remove actionable from post" do
    # First mark as actionable
    PostAction.act(user, post, PostActionType.types[:actionable])
    post.update_actionable_count

    visit "/t/#{topic.slug}/#{topic.id}"

    within(".post-controls") do
      expect(page).to have_css(".has-actionable")

      find(".toggle-actionable").click

      # Should change back to un-actioned state
      expect(page).to have_css(".actionable")
      expect(page).to have_css(".d-icon-far-check-square")
      expect(page).not_to have_content("1") # Count should be hidden
    end

    # Verify database changes
    expect(
      PostAction.exists?(
        post: post,
        user: user,
        post_action_type_id: PostActionType.types[:actionable],
        deleted_at: nil,
      ),
    ).to be false
  end

  it "shows who actioned when count is clicked" do
    # Create multiple actionable actions
    user2 = Fabricate(:user)
    PostAction.act(user, post, PostActionType.types[:actionable])
    PostAction.act(user2, post, PostActionType.types[:actionable])
    post.update_actionable_count

    visit "/t/#{topic.slug}/#{topic.id}"

    within(".post-controls") do
      expect(page).to have_content("2")

      find(".actionable-count").click

      # Should show user avatars
      expect(page).to have_css(".who-actioned")
      expect(page).to have_css(".avatar", count: 2)
    end
  end

  it "prevents actioning own posts" do
    own_post = Fabricate(:post, topic: topic, user: user)

    visit "/t/#{topic.slug}/#{topic.id}"

    within("#post_#{own_post.post_number}") { expect(page).not_to have_css(".toggle-actionable") }
  end

  it "shows disabled state when user cannot act" do
    SiteSetting.actionable_min_trust_level = 4

    visit "/t/#{topic.slug}/#{topic.id}"

    within(".post-controls") do
      button = find(".toggle-actionable")
      expect(button[:disabled]).to eq("true")
    end
  end

  it "hides button when actionable is disabled" do
    SiteSetting.actionable_enabled = false

    visit "/t/#{topic.slug}/#{topic.id}"

    within(".post-controls") { expect(page).not_to have_css(".toggle-actionable") }
  end

  it "shows animation when toggling" do
    visit "/t/#{topic.slug}/#{topic.id}"

    within(".post-controls") do
      button = find(".toggle-actionable")
      button.click

      # Should show animation class briefly
      expect(page).to have_css(".check-animation", wait: 0.1)
    end
  end

  it "handles errors gracefully" do
    # Mock server error
    page.driver.browser.url_blacklist = ["/actionable/*"]

    visit "/t/#{topic.slug}/#{topic.id}"

    within(".post-controls") do
      find(".toggle-actionable").click

      # Should show error message
      expect(page).to have_css(".alert-error", wait: 2)
    end
  end

  it "updates in real-time when others act" do
    visit "/t/#{topic.slug}/#{topic.id}"

    # Simulate another user marking as actionable
    PostAction.act(Fabricate(:user), post, PostActionType.types[:actionable])
    post.update_actionable_count

    # Trigger MessageBus update
    page.execute_script(
      "" \
        "
      window.MessageBus.trigger('post-stream:refresh', {
        messageType: 'actioned',
        id: #{post.id},
        actionable_count: 1
      });
    " \
        "",
    )

    within(".post-controls") { expect(page).to have_content("1") }
  end

  context "when on mobile" do
    before do
      page.driver.browser.manage.window.resize_to(375, 667) # iPhone size
    end

    it "works on mobile devices" do
      visit "/t/#{topic.slug}/#{topic.id}"

      within(".post-controls") do
        expect(page).to have_css(".toggle-actionable")

        find(".toggle-actionable").click
        expect(page).to have_css(".has-actionable")
      end
    end
  end

  context "with accessibility features" do
    it "has proper ARIA labels" do
      visit "/t/#{topic.slug}/#{topic.id}"

      button = find(".toggle-actionable")
      expect(button[:title]).to include("actionable")
      expect(button[:role]).to eq("button")
    end

    it "is keyboard accessible" do
      visit "/t/#{topic.slug}/#{topic.id}"

      # Tab to the button and press Enter
      page.execute_script("document.querySelector('.toggle-actionable').focus()")
      page.send_keys(:enter)

      expect(page).to have_css(".has-actionable")
    end

    it "has proper focus styles" do
      visit "/t/#{topic.slug}/#{topic.id}"

      page.execute_script("document.querySelector('.toggle-actionable').focus()")

      button = find(".toggle-actionable")
      expect(button).to match_css(":focus")
    end
  end
end
