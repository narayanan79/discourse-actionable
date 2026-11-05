import { withPluginApi } from "discourse/lib/plugin-api";
import ActionableButton from "../components/actionable-button.gjs";

const MESSAGE_TYPES = ["actioned", "unactioned"];

export default {
  name: "discourse-actionable",

  initialize(owner) {
    const siteSettings = owner.lookup("service:site-settings");
    if (!siteSettings.actionable_enabled) {
      return;
    }

    withPluginApi((api) => {
      api.addTrackedPostProperties(
        "actionable_count",
        "actioned",
        "can_toggle_actionable"
      );

      api.registerValueTransformer(
        "post-menu-buttons",
        ({ value: dag, context: { post } }) => {
          if (post) {
            dag.add("actionable", ActionableButton, {
              before: ["reply", "share", "flag"],
            });
          }
          return dag;
        }
      );

      // One handler per message type for the whole topic, instead of one
      // MessageBus subscription per rendered post.
      MESSAGE_TYPES.forEach((type) => {
        api.registerCustomPostMessageCallback(type, (topicController, data) => {
          const post = topicController
            .get("model.postStream")
            ?.findLoadedPost(data.id);

          if (!post || data.actionable_count === undefined) {
            return;
          }

          post.actionable_count = data.actionable_count;

          // The same user acting from another tab or device.
          if (data.actioned_by === api.getCurrentUser()?.id) {
            post.actioned = type === "actioned";
          }
        });
      });
    });
  },
};
