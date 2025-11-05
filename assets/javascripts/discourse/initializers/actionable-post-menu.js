import { withPluginApi } from "discourse/lib/plugin-api";
import ActionableButton from "../components/actionable-button";

export default {
  name: "actionable-post-menu",

  initialize() {
    withPluginApi("1.34.0", (api) => {
      // Register actionable button using value transformer
      api.registerValueTransformer("post-menu-buttons", ({ value: dag, context }) => {
        const post = context.post;

        if (!post) {
          return dag;
        }

        // Add actionable button to the DAG
        dag.add("actionable", ActionableButton, {
          before: ["reply", "share", "flag"]
        });

        return dag;
      });
    });
  }
};