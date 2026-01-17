import Component from "@glimmer/component";
import { service } from "@ember/service";
import UserSummarySection from "discourse/components/user-summary-section";
import UserSummaryUser from "discourse/components/user-summary-user";
import UserSummaryUsersList from "discourse/components/user-summary-users-list";

export default class ActionableSummarySections extends Component {
  @service siteSettings;

  <template>
    {{#if this.siteSettings.actionable_enabled}}
      <div class="top-section most-actionabled-section">
        <UserSummarySection
          @title="most_actionabled_by"
          class="summary-user-list actionabled-by-section pull-left"
        >
          <UserSummaryUsersList
            @none="no_actionables"
            @users={{@outletArgs.model.most_actionabled_by_users}}
            as |user|
          >
            <UserSummaryUser
              @user={{user}}
              @icon="bullseye"
              @countClass="actionables"
            />
          </UserSummaryUsersList>
        </UserSummarySection>

        <UserSummarySection
          @title="most_actionabled_users"
          class="summary-user-list actionabled-section pull-right"
        >
          <UserSummaryUsersList
            @none="no_actionables"
            @users={{@outletArgs.model.most_actionabled_users}}
            as |user|
          >
            <UserSummaryUser
              @user={{user}}
              @icon="bullseye"
              @countClass="actionables"
            />
          </UserSummaryUsersList>
        </UserSummarySection>
      </div>
    {{/if}}
  </template>
}
