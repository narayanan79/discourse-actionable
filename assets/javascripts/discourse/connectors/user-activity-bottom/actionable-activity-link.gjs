import Component from "@glimmer/component";
import { service } from "@ember/service";
import DNavigationItem from "discourse/components/d-navigation-item";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ActionableActivityLink extends Component {
  @service siteSettings;

  <template>
    {{#if this.siteSettings.actionable_enabled}}
      <DNavigationItem
        @route="userActivity.actionableGiven"
        @ariaCurrentContext="subNav"
        class="user-nav__activity-actionable"
      >
        {{icon "bullseye"}}
        <span>{{i18n "user_action_groups.18"}}</span>
      </DNavigationItem>
    {{/if}}
  </template>
}