import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  acceptance,
  loggedInUser,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Actionable Button", function (needs) {
  needs.user();
  needs.settings({ actionable_enabled: true });

  let post;

  needs.hooks.beforeEach(() => {
    post = {
      id: 1,
      topic_id: 1,
      show_actionable: true,
      actioned: false,
      actionable_count: 0,
      can_undo_actionable: false,
      can_toggle_actionable: true,
    };

    pretender.get("/t/1.json", () => {
      return response({
        post_stream: {
          posts: [post],
        },
        id: 1,
      });
    });
  });

  test("displays actionable button when enabled", async function (assert) {
    await visit("/t/topic/1");
    
    assert
      .dom(".post-action-menu__actionable")
      .exists("actionable button is present");
    
    assert
      .dom(".post-action-menu__actionable .d-icon-far-square-check")
      .exists("shows outline check icon when not actioned");
  });

  test("clicking actionable button creates action", async function (assert) {
    pretender.post("/actionable/1", () => {
      post.actioned = true;
      post.actionable_count = 1;
      post.can_undo_actionable = true;
      
      return response({
        success: true,
        acted: true,
        actionable_count: 1,
        can_undo_actionable: true,
      });
    });

    await visit("/t/topic/1");
    await click(".post-action-menu__actionable");

    assert
      .dom(".post-action-menu__actionable .d-icon-square-check")
      .exists("shows solid check icon when actioned");
    
    assert
      .dom(".post-action-menu__actionable.has-actionable")
      .exists("has actioned state class");
    
    assert
      .dom(".actionable-count")
      .hasText("1", "displays correct count");
  });

  test("clicking actionable button again removes action", async function (assert) {
    // Start with actioned state
    post.actioned = true;
    post.actionable_count = 1;
    post.can_undo_actionable = true;

    pretender.delete("/actionable/1", () => {
      post.actioned = false;
      post.actionable_count = 0;
      post.can_undo_actionable = false;
      
      return response({
        success: true,
        acted: false,
        actionable_count: 0,
        can_undo_actionable: false,
      });
    });

    await visit("/t/topic/1");
    await click(".post-action-menu__actionable");

    assert
      .dom(".post-action-menu__actionable .d-icon-far-square-check")
      .exists("shows outline check icon when not actioned");
    
    assert
      .dom(".post-action-menu__actionable.actionable")
      .exists("has non-actioned state class");
    
    assert
      .dom(".actionable-count")
      .doesNotExist("count is hidden when zero");
  });

  test("shows colored icon when user has actioned and can undo", async function (assert) {
    post.actioned = true;
    post.actionable_count = 1;
    post.can_undo_actionable = true;

    await visit("/t/topic/1");

    assert
      .dom(".post-action-menu__actionable.actionable-by-me")
      .exists("has colored state class for user's own action");
  });

  test("prevents undo when timeout expired", async function (assert) {
    post.actioned = true;
    post.actionable_count = 1;
    post.can_undo_actionable = false; // Timeout expired

    await visit("/t/topic/1");

    assert
      .dom(".post-action-menu__actionable")
      .hasAttribute("disabled", "", "button is disabled when timeout expired");
    
    assert
      .dom(".post-action-menu__actionable.has-actionable")
      .exists("still shows actioned state");
    
    assert
      .dom(".post-action-menu__actionable.actionable-by-me")
      .doesNotExist("does not show colored state when cannot undo");
  });

  test("displays actionable count correctly", async function (assert) {
    post.actionable_count = 5;

    await visit("/t/topic/1");

    assert
      .dom(".actionable-count")
      .hasText("5", "displays correct count");
    
    assert
      .dom(".actionable-count.regular-actionables")
      .exists("has regular count styling when user hasn't actioned");
  });

  test("displays count with user action included", async function (assert) {
    post.actioned = true;
    post.actionable_count = 3;
    post.can_undo_actionable = true;

    await visit("/t/topic/1");

    assert
      .dom(".actionable-count")
      .hasText("3", "displays total count including user");
    
    assert
      .dom(".actionable-count.my-actionables")
      .exists("has user count styling when user has actioned");
  });

  test("handles real-time updates via MessageBus", async function (assert) {
    await visit("/t/topic/1");

    // Simulate another user actioning the post
    const messageData = {
      type: "actioned",
      id: 1,
      actioned_by: 999, // Different user
      actionable_count: 1,
    };

    publishToMessageBus("/topic/1", messageData);

    assert
      .dom(".actionable-count")
      .hasText("1", "count updates in real-time");
    
    assert
      .dom(".post-action-menu__actionable.actionable")
      .exists("maintains user's non-actioned state");
  });

  test("handles real-time updates for user's own actions", async function (assert) {
    const currentUserId = loggedInUser().id;
    
    await visit("/t/topic/1");

    // Simulate current user actioning the post from another tab
    const messageData = {
      type: "actioned",
      id: 1,
      actioned_by: currentUserId,
      actionable_count: 1,
    };

    publishToMessageBus("/topic/1", messageData);

    assert
      .dom(".actionable-count")
      .hasText("1", "count updates in real-time");
    
    assert
      .dom(".post-action-menu__actionable.has-actionable")
      .exists("updates user's actioned state");
  });

  test("hides button when actionable is disabled", async function (assert) {
    post.show_actionable = false;

    await visit("/t/topic/1");

    assert
      .dom(".post-action-menu__actionable")
      .doesNotExist("button is hidden when disabled");
    
    // Count should still show if there are existing actions
    post.actionable_count = 2;
    await visit("/t/topic/1");
    
    assert
      .dom(".actionable-count")
      .hasText("2", "count still displays when button is hidden");
  });

  test("handles API errors gracefully", async function (assert) {
    pretender.post("/actionable/1", () => {
      return response(422, {
        success: false,
        errors: ["Something went wrong"],
      });
    });

    await visit("/t/topic/1");
    await click(".post-action-menu__actionable");

    // Should still show original state after error
    assert
      .dom(".post-action-menu__actionable .d-icon-far-square-check")
      .exists("maintains original state after error");
    
    assert
      .dom(".post-action-menu__actionable.actionable")
      .exists("does not change state after error");
  });

  test("shows loading state during API call", async function (assert) {
    let resolveRequest;
    const requestPromise = new Promise((resolve) => {
      resolveRequest = resolve;
    });

    pretender.post("/actionable/1", () => {
      return requestPromise.then(() =>
        response({
          success: true,
          acted: true,
          actionable_count: 1,
          can_undo_actionable: true,
        })
      );
    });

    await visit("/t/topic/1");
    
    // Start the click but don't await it yet
    const clickPromise = click(".post-action-menu__actionable");

    // Check loading state
    assert
      .dom(".post-action-menu__actionable.loading")
      .exists("shows loading state during API call");
    
    assert
      .dom(".post-action-menu__actionable")
      .hasAttribute("disabled", "", "button is disabled during loading");

    // Resolve the request and wait for click to complete
    resolveRequest();
    await clickPromise;

    assert
      .dom(".post-action-menu__actionable.loading")
      .doesNotExist("removes loading state after API call");
  });
});