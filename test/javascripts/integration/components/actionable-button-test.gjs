import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import ActionableButton from "discourse/plugins/discourse-actionable/discourse/components/actionable-button";

// Stand-in for the Post model with the properties the plugin tracks.
class TestPost {
  @tracked actionable_count = 0;
  @tracked actioned = false;
  @tracked can_toggle_actionable = true;

  id = 1;
  show_actionable = true;
  topic = { archived: false };

  constructor(attrs = {}) {
    Object.assign(this, attrs);
  }
}

module(
  "Discourse Actionable | Integration | Component | actionable-button",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.actionable_show_who_actioned = true;
    });

    test("renders an enabled button for a post the user can mark", async function (assert) {
      this.post = new TestPost();

      await render(
        <template><ActionableButton @post={{this.post}} /></template>
      );

      assert
        .dom(".post-action-menu__actionable")
        .hasClass("actionable")
        .isNotDisabled();
      assert.dom(".actionable-count").doesNotExist("no count when zero");
    });

    test("marks the post and updates the post model", async function (assert) {
      this.post = new TestPost();
      pretender.post("/actionable/1", () =>
        response({
          success: true,
          actionable_count: 1,
          actioned: true,
          can_toggle_actionable: true,
        })
      );

      await render(
        <template><ActionableButton @post={{this.post}} /></template>
      );
      await click(".post-action-menu__actionable");

      assert.dom(".post-action-menu__actionable").hasClass("has-actionable");
      assert.dom(".actionable-count").hasText("1");
      assert.true(this.post.actioned, "post model is updated");
    });

    test("unmarks a post the user has marked", async function (assert) {
      this.post = new TestPost({ actionable_count: 1, actioned: true });
      pretender.delete("/actionable/1", () =>
        response({
          success: true,
          actionable_count: 0,
          actioned: false,
          can_toggle_actionable: true,
        })
      );

      await render(
        <template><ActionableButton @post={{this.post}} /></template>
      );
      await click(".post-action-menu__actionable");

      assert.dom(".post-action-menu__actionable").hasClass("actionable");
      assert.dom(".actionable-count").doesNotExist();
    });

    test("shows later count changes made outside the component", async function (assert) {
      this.post = new TestPost();
      pretender.post("/actionable/1", () =>
        response({
          success: true,
          actionable_count: 1,
          actioned: true,
          can_toggle_actionable: true,
        })
      );

      await render(
        <template><ActionableButton @post={{this.post}} /></template>
      );
      await click(".post-action-menu__actionable");

      // e.g. a MessageBus update after someone else marked the post
      this.post.actionable_count = 2;
      await settled();

      assert.dom(".actionable-count").hasText("2");
    });

    test("shows the server's error message and keeps the state", async function (assert) {
      this.post = new TestPost();
      const dialog = getOwner(this).lookup("service:dialog");
      const alert = sinon.stub(dialog, "alert");
      pretender.post("/actionable/1", () =>
        response(403, { success: false, errors: ["Not allowed here"] })
      );

      await render(
        <template><ActionableButton @post={{this.post}} /></template>
      );
      await click(".post-action-menu__actionable");

      assert.true(alert.calledWith("Not allowed here"), "shows the message");
      assert.dom(".post-action-menu__actionable").hasClass("actionable");
      assert.false(this.post.actioned);
    });

    test("is disabled when the user cannot toggle", async function (assert) {
      this.post = new TestPost({
        actionable_count: 1,
        actioned: true,
        can_toggle_actionable: false,
      });

      await render(
        <template><ActionableButton @post={{this.post}} /></template>
      );

      assert.dom(".post-action-menu__actionable").isDisabled();
      assert
        .dom(".post-action-menu__actionable")
        .hasAttribute("title", i18n("post.controls.has_actioned"));
    });

    test("lists who marked the post when the count is clicked", async function (assert) {
      this.post = new TestPost({ actionable_count: 1 });
      pretender.get("/actionable/1/who", () =>
        response({
          users: [{ id: 2, username: "sam", avatar_template: "/a/{size}.png" }],
          total_count: 1,
        })
      );

      await render(
        <template><ActionableButton @post={{this.post}} /></template>
      );
      await click(".actionable-count");

      assert.dom(".who-actioned").hasClass("--expanded");
      assert.dom(".who-actioned [data-user-card='sam']").exists();
    });

    test("does not offer the list when the site hides it", async function (assert) {
      this.siteSettings.actionable_show_who_actioned = false;
      this.post = new TestPost({ actionable_count: 1 });

      await render(
        <template><ActionableButton @post={{this.post}} /></template>
      );

      assert.dom(".actionable-count").isDisabled();
    });

    test("shows only the count when the button is not shown", async function (assert) {
      this.post = new TestPost({ actionable_count: 2, show_actionable: false });

      await render(
        <template><ActionableButton @post={{this.post}} /></template>
      );

      assert.dom(".post-action-menu__actionable").doesNotExist();
      assert.dom(".actionable-count").hasText("2");
    });

    test("shouldRender", function (assert) {
      assert.true(
        ActionableButton.shouldRender({ post: new TestPost() }),
        "renders when the button is shown"
      );
      assert.true(
        ActionableButton.shouldRender({
          post: new TestPost({ show_actionable: false, actionable_count: 1 }),
        }),
        "renders the count of existing marks"
      );
      assert.false(
        ActionableButton.shouldRender({
          post: new TestPost({ show_actionable: false }),
        }),
        "renders nothing otherwise"
      );
    });
  }
);

module(
  "Discourse Actionable | Integration | Component | actionable-button | anonymous",
  function (hooks) {
    setupRenderingTest(hooks, { anonymous: true });

    test("asks anonymous users to log in instead of sending a request", async function (assert) {
      this.post = new TestPost({ can_toggle_actionable: false });
      this.showLogin = sinon.spy();
      const request = sinon.spy();
      pretender.post("/actionable/1", () => {
        request();
        return response({});
      });

      await render(
        <template>
          <ActionableButton
            @buttonActions={{hash showLogin=this.showLogin}}
            @post={{this.post}}
          />
        </template>
      );
      await click(".post-action-menu__actionable");

      assert.true(this.showLogin.calledOnce, "login is requested");
      assert.false(request.called, "no request is sent");
    });
  }
);
