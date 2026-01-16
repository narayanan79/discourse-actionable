import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "actionable-routes",

  initialize() {
    withPluginApi("1.14.0", (api) => {
      // Register routes for actionable activity pages
      api.addUserActivityRoute("actionableGiven", {
        path: "/activity/actionable-given",
        userActionType: 18,
      });

      api.addUserActivityRoute("actionableReceived", {
        path: "/activity/actionable-received",
        userActionType: 19,
      });
    });
  },
};
