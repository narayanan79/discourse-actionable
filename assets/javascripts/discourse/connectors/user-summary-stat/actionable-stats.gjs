import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { and } from "truth-helpers";
import UserStat from "discourse/components/user-stat";

export default class ActionableStats extends Component {
  @service siteSettings;

  <template>
    {{#if this.siteSettings.actionable_enabled}}
      {{#if @outletArgs.model.actionable_given}}
        <li class="user-summary-stat-outlet actionable-given linked-stat">
          <LinkTo @route="userActivity.actionableGiven">
            <UserStat
              @value={{@outletArgs.model.actionable_given}}
              @label="user.summary.actionable_given.other"
              @icon="bullseye"
            />
          </LinkTo>
        </li>
      {{/if}}
      {{#if @outletArgs.model.actionable_received}}
        <li class="user-summary-stat-outlet actionable-received linked-stat">
          <LinkTo @route="userActivity.actionableReceived">
            <UserStat
              @value={{@outletArgs.model.actionable_received}}
              @label="user.summary.actionable_received.other"
              @icon="bullseye"
            />
          </LinkTo>
        </li>
      {{/if}}
    {{/if}}
  </template>
}
