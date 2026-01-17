import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import UserStat from "discourse/components/user-stat";

export default class ActionableStats extends Component {
  @service siteSettings;

  <template>
    {{#if this.siteSettings.actionable_enabled}}
      {{#if @outletArgs.model.can_see_user_actions}}
        <li class="stats-actionable-given linked-stat">
          <LinkTo @route="userActivity.actionableGiven">
            <UserStat
              @value={{@outletArgs.model.actionable_given}}
              @icon="bullseye"
              @label="user.summary.actionable_given"
            />
          </LinkTo>
        </li>
      {{else}}
        <li class="stats-actionable-given">
          <UserStat
            @value={{@outletArgs.model.actionable_given}}
            @icon="bullseye"
            @label="user.summary.actionable_given"
          />
        </li>
      {{/if}}
      <li class="stats-actionable-received">
        <UserStat
          @value={{@outletArgs.model.actionable_received}}
          @icon="bullseye"
          @label="user.summary.actionable_received"
        />
      </li>
    {{/if}}
  </template>
}
