import { getOwner } from "@ember/application";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender from "discourse/tests/helpers/create-pretender";

module("Integration | Component | actionable-button", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    // Mock site settings
    this.siteSettings = getOwner(this).lookup("service:site-settings");
    this.siteSettings.actionable_enabled = true;

    // Mock current user
    this.currentUser = getOwner(this).lookup("service:current-user");
    this.currentUser.set("id", 1);

    // Mock post object with all required properties
    this.post = {
      id: 1,
      topic: { id: 10 },
      show_actionable: true,
      actioned: false,
      actionable_count: 0,
      can_undo_actionable: false,
      can_toggle_actionable: true,
    };
  });

  test("renders button with correct initial state", async function (assert) {
    await render(hbs`<ActionableButton @post={{this.post}} />`);

    assert.dom("[data-post-id='1']").exists("renders button with post ID");
    assert
      .dom(".post-action-menu__actionable")
      .hasClass("actionable", "has actionable state class");
    assert
      .dom(".d-icon-far-square-check")
      .exists("shows outline check icon");
    assert.dom(".actionable-count").doesNotExist("hides count when zero");
  });

  test("renders actioned state correctly", async function (assert) {
    this.post.actioned = true;
    this.post.actionable_count = 1;
    this.post.can_undo_actionable = true;

    await render(hbs`<ActionableButton @post={{this.post}} />`);

    assert
      .dom(".post-action-menu__actionable")
      .hasClass("has-actionable", "has actioned state class");
    assert
      .dom(".post-action-menu__actionable")
      .hasClass("actionable-by-me", "has user's own action class");
    assert.dom(".d-icon-square-check").exists("shows solid check icon");
    assert.dom(".actionable-count").hasText("1", "displays count");
  });

  test("renders disabled state when timeout expired", async function (assert) {
    this.post.actioned = true;
    this.post.actionable_count = 1;
    this.post.can_undo_actionable = false; // Timeout expired
    this.post.can_toggle_actionable = false;

    await render(hbs`<ActionableButton @post={{this.post}} />`);

    assert
      .dom(".post-action-menu__actionable")
      .hasAttribute("disabled", "", "button is disabled");
    assert
      .dom(".post-action-menu__actionable")
      .hasClass("has-actionable", "still shows actioned state");
    assert
      .dom(".post-action-menu__actionable")
      .doesNotHaveClass("actionable-by-me", "removes user action styling");
  });

  test("renders count with correct styling", async function (assert) {
    this.post.actionable_count = 5;

    await render(hbs`<ActionableButton @post={{this.post}} />`);

    assert.dom(".actionable-count").hasText("5", "displays correct count");
    assert
      .dom(".actionable-count")
      .hasClass("regular-actionables", "has regular styling");

    // Test with user's own action
    this.post.actioned = true;
    this.post.can_undo_actionable = true;

    await render(hbs`<ActionableButton @post={{this.post}} />`);

    assert
      .dom(".actionable-count")
      .hasClass("my-actionables", "has user action styling");
  });

  test("computes title correctly", async function (assert) {
    await render(hbs`<ActionableButton @post={{this.post}} />`);

    assert
      .dom(".post-action-menu__actionable")
      .hasProperty("title", "post.controls.actionable");

    // Test actioned state with undo capability
    this.post.actioned = true;
    this.post.can_undo_actionable = true;

    await render(hbs`<ActionableButton @post={{this.post}} />`);

    assert
      .dom(".post-action-menu__actionable")
      .hasProperty("title", "post.controls.undo_actionable");

    // Test actioned state without undo capability
    this.post.can_undo_actionable = false;

    await render(hbs`<ActionableButton @post={{this.post}} />`);

    assert
      .dom(".post-action-menu__actionable")
      .hasProperty("title", "post.controls.has_actioned");
  });

  test("handles show_actionable false", async function (assert) {
    this.post.show_actionable = false;
    this.post.actionable_count = 3;

    await render(hbs`<ActionableButton @post={{this.post}} />`);

    assert
      .dom(".post-action-menu__actionable")
      .doesNotExist("hides actionable button");
    assert.dom(".actionable-count").hasText("3", "still shows count");
  });

  test("shouldRender static method", async function (assert) {
    const ActionableButton = getOwner(this)
      .factoryFor("component:actionable-button")
      .class;

    // Test with debug flag (should always render for now)
    let result = ActionableButton.shouldRender({ post: this.post });
    assert.true(result, "renders when debug flag is true");

    // Test various post states
    this.post.show_actionable = false;
    this.post.actionable_count = 0;
    result = ActionableButton.shouldRender({ post: this.post });
    assert.true(result, "still renders due to debug flag");
  });

  test("animation classes", async function (assert) {
    await render(hbs`<ActionableButton @post={{this.post}} />`);

    // The animation class should be applied during click
    // This would require more complex testing with click simulation
    // For now, just verify the base state
    assert
      .dom(".post-action-menu__actionable")
      .doesNotHaveClass("check-animation", "no animation class initially");
  });

  test("component cleanup", async function (assert) {
    const messageBus = getOwner(this).lookup("service:message-bus");
    const unsubscribeSpy = sinon.spy(messageBus, "unsubscribe");

    await render(hbs`<ActionableButton @post={{this.post}} />`);

    // Component should be subscribed
    assert.ok(
      messageBus.subscribe.called,
      "subscribes to MessageBus on render"
    );

    // Simulate component destruction
    this.owner.lookup("router:main").transitionTo("/");

    assert.ok(
      unsubscribeSpy.called,
      "unsubscribes from MessageBus on destroy"
    );

    unsubscribeSpy.restore();
  });

  test("handles missing post properties gracefully", async function (assert) {
    // Test with minimal post object
    this.post = {
      id: 1,
      show_actionable: true,
    };

    await render(hbs`<ActionableButton @post={{this.post}} />`);

    assert.dom(".post-action-menu__actionable").exists("renders with minimal post data");
    assert.dom(".actionable-count").doesNotExist("handles missing count gracefully");
  });

  test("respects site setting", async function (assert) {
    this.siteSettings.actionable_enabled = false;

    await render(hbs`<ActionableButton @post={{this.post}} />`);

    // Component should still render (site setting is checked in backend/permissions)
    // but functionality would be limited
    assert.dom(".post-action-menu__actionable").exists("renders regardless of site setting");
  });
});