import { _addTrackedPostProperty } from "discourse/models/post";

export default {
  name: "extend-post-model-for-actionable",

  initialize() {
    // Add tracked properties for actionable
    _addTrackedPostProperty("actionableAction");
    _addTrackedPostProperty("actionable_count");
    _addTrackedPostProperty("actioned");
    _addTrackedPostProperty("can_toggle_actionable");
  },
};
