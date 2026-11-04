import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DUserStat from "discourse/ui-kit/d-user-stat";

export default class ActionableStats extends Component {
  @service siteSettings;

  <template>
    {{#if this.siteSettings.actionable_enabled}}
      {{#if @outletArgs.model.can_see_user_actions}}
        <li class="stats-actionable-given linked-stat">
          <LinkTo @route="userActivity.actionableGiven">
            <DUserStat
              @icon="bullseye"
              @label="user.summary.actionable_given"
              @value={{@outletArgs.model.actionable_given}}
            />
          </LinkTo>
        </li>
      {{else}}
        <li class="stats-actionable-given">
          <DUserStat
            @icon="bullseye"
            @label="user.summary.actionable_given"
            @value={{@outletArgs.model.actionable_given}}
          />
        </li>
      {{/if}}
      <li class="stats-actionable-received">
        <DUserStat
          @icon="bullseye"
          @label="user.summary.actionable_received"
          @value={{@outletArgs.model.actionable_received}}
        />
      </li>
    {{/if}}
  </template>
}
