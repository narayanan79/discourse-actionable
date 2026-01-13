import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "actionable-icons",

  initialize() {
    withPluginApi("1.6.0", (api) => {
      // Register actionable icons in the icon library
      api.replaceIcon("d-unactioned", "far-check-square");
      api.replaceIcon("d-actioned", "check-square");

      // Alternative icons that can be used
      // api.replaceIcon("d-unactioned", "far-square");
      // api.replaceIcon("d-actioned", "check");

      // Note: Icon styles have been moved to actionable.scss
      // No need for dynamic CSS injection
    });
  },
};
