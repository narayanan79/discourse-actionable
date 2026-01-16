import Component from "@glimmer/component";
import DNavigationItem from "discourse/components/d-navigation-item";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ActionableActivityLinks extends Component {
  @service siteSettings;

  <template>
    {{#if this.siteSettings.actionable_enabled}}
      <DNavigationItem
        @route="userActivity.actionableGiven"
        @ariaCurrentContext="subNav"
        class="user-nav__activity-actionable-given"
      >
        {{icon "tasks"}}
        <span>{{i18n "user_action_groups.18"}}</span>
      </DNavigationItem>
      <DNavigationItem
        @route="userActivity.actionableReceived"
        @ariaCurrentContext="subNav"
        class="user-nav__activity-actionable-received"
      >
        {{icon "inbox"}}
        <span>{{i18n "user_action_groups.19"}}</span>
      </DNavigationItem>
    {{/if}}
  </template>
}
