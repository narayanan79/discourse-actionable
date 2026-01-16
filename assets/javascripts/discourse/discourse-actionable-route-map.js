export default {
  resource: "user.userActivity",
  map() {
    this.route("actionableGiven", { path: "actionable-given" });
    this.route("actionableReceived", { path: "actionable-received" });
  },
};
