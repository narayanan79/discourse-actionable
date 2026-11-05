import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import {
  acceptance,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

const TOPIC_URL = "/t/internationalization-localization/280";
const FIRST_POST_ID = 398;

function topicWithActionables(postAttrs = {}) {
  const topic = cloneJSON(topicFixtures["/t/280/1.json"]);
  topic.post_stream.posts.forEach((post) =>
    Object.assign(
      post,
      {
        show_actionable: true,
        actionable_count: 0,
        actioned: false,
        can_toggle_actionable: true,
      },
      postAttrs
    )
  );
  return topic;
}

acceptance("Discourse Actionable | post menu", function (needs) {
  needs.user();
  needs.settings({
    actionable_enabled: true,
    actionable_show_who_actioned: true,
  });

  needs.pretender((server, helper) => {
    server.get("/t/280.json", () => helper.response(topicWithActionables()));
    server.post(`/actionable/${FIRST_POST_ID}`, () =>
      helper.response({
        success: true,
        actionable_count: 1,
        actioned: true,
        can_toggle_actionable: true,
      })
    );
    server.get(`/actionable/${FIRST_POST_ID}/who`, () =>
      helper.response({
        users: [{ id: 2, username: "sam", avatar_template: "/a/{size}.png" }],
        total_count: 1,
      })
    );
  });

  test("marks a post as actionable", async function (assert) {
    await visit(TOPIC_URL);
    await click("#post_1 .post-action-menu__actionable");

    assert
      .dom("#post_1 .post-action-menu__actionable")
      .hasClass("has-actionable");
    assert.dom("#post_1 .actionable-count").hasText("1");
  });

  test("applies real-time updates from other users", async function (assert) {
    await visit(TOPIC_URL);

    await publishToMessageBus("/topic/280", {
      type: "actioned",
      id: FIRST_POST_ID,
      actionable_count: 3,
      actioned_by: 999,
    });

    assert.dom("#post_1 .actionable-count").hasText("3");
    assert
      .dom("#post_1 .post-action-menu__actionable")
      .hasClass("actionable", "the viewer's own state is unchanged");
  });

  test("keeps applying real-time updates after the user toggled", async function (assert) {
    await visit(TOPIC_URL);
    await click("#post_1 .post-action-menu__actionable");

    await publishToMessageBus("/topic/280", {
      type: "actioned",
      id: FIRST_POST_ID,
      actionable_count: 4,
      actioned_by: 999,
    });

    assert.dom("#post_1 .actionable-count").hasText("4");
  });

  test("reflects the user's own action from another tab", async function (assert) {
    await visit(TOPIC_URL);

    await publishToMessageBus("/topic/280", {
      type: "actioned",
      id: FIRST_POST_ID,
      actionable_count: 1,
      actioned_by: 19,
    });

    assert
      .dom("#post_1 .post-action-menu__actionable")
      .hasClass("has-actionable");
  });

  test("lists who marked a post", async function (assert) {
    await visit(TOPIC_URL);
    await click("#post_1 .post-action-menu__actionable");
    await click("#post_1 .actionable-count");

    assert.dom("#post_1 .who-actioned").hasClass("--expanded");
    assert.dom("#post_1 .who-actioned [data-user-card='sam']").exists();
  });
});

acceptance("Discourse Actionable | post menu | anonymous", function (needs) {
  needs.settings({ actionable_enabled: true });

  needs.pretender((server, helper) => {
    server.get("/t/280.json", () =>
      helper.response(topicWithActionables({ can_toggle_actionable: false }))
    );
  });

  test("sends anonymous visitors to the login page", async function (assert) {
    await visit(TOPIC_URL);
    await click("#post_1 .post-action-menu__actionable");

    assert.strictEqual(currentURL(), "/login");
  });
});

acceptance("Discourse Actionable | activity tabs", function (needs) {
  needs.user();
  needs.settings({ actionable_enabled: true });

  needs.pretender((server, helper) => {
    server.get("/user_actions.json", () =>
      helper.response({ user_actions: [] })
    );
  });

  test("shows an empty state for actionables given", async function (assert) {
    await visit("/u/eviltrout/activity/actionable-given");

    assert
      .dom(".empty-state .empty-state__title")
      .hasText(i18n("user_activity.no_actionable_given_title"));
  });

  test("shows an empty state for another user's actionables received", async function (assert) {
    await visit("/u/charlie/activity/actionable-received");

    assert.dom(".empty-state .empty-state__title").hasText(
      i18n("user_activity.no_actionable_received_title_others", {
        username: "charlie",
      })
    );
  });
});
