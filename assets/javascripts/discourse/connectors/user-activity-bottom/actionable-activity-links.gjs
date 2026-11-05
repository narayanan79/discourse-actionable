import Component from "@glimmer/component";
import { service } from "@ember/service";
import DNavigationItem from "discourse/ui-kit/d-navigation-item";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ActionableActivityLinks extends Component {
  @service siteSettings;

  <template>
    {{#if this.siteSettings.actionable_enabled}}
      <DNavigationItem
        class="user-nav__activity-actionable-given"
        @ariaCurrentContext="subNav"
        @route="userActivity.actionableGiven"
      >
        {{dIcon "bullseye"}}
        <span>{{i18n "user_action_groups.18"}}</span>
      </DNavigationItem>
      <DNavigationItem
        class="user-nav__activity-actionable-received"
        @ariaCurrentContext="subNav"
        @route="userActivity.actionableReceived"
      >
        {{dIcon "bullseye"}}
        <span>{{i18n "user_action_groups.19"}}</span>
      </DNavigationItem>
    {{/if}}
  </template>
}
