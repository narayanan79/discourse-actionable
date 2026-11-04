import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import discourseLater from "discourse/lib/later";
import { and, eq, not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DSmallUserList, {
  smallUserAttrs,
} from "discourse/ui-kit/d-small-user-list";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dCloseOnClickOutside from "discourse/ui-kit/modifiers/d-close-on-click-outside";
import { i18n } from "discourse-i18n";

const ActionableCount = <template>
  <button
    aria-expanded={{if @expanded "true" "false"}}
    aria-label={{i18n "post.sr_post_actionable_count_button" count=@count}}
    class={{dConcatClass
      "post-action-menu__actionable-count"
      "actionable-count"
      "button-count"
      "highlight-action"
      (if @actioned "my-actionables" "regular-actionables")
      (unless @clickable "who-actioned-disabled")
    }}
    disabled={{not @clickable}}
    id={{@elementId}}
    title={{@title}}
    type="button"
    ...attributes
    {{on "click" @onClick}}
  >
    {{@count}}
  </button>
</template>;

/**
 * Post menu button to mark a post as actionable, with its count and the list
 * of users who marked it.
 *
 * The tracked post properties (`actionable_count`, `actioned`,
 * `can_toggle_actionable`) are the single source of truth: they are updated
 * from the server response and from MessageBus (see the initializer), so the
 * button never shows stale local state.
 */
export default class ActionableButton extends Component {
  static shouldRender(args) {
    return args.post.show_actionable || args.post.actionable_count > 0;
  }

  @service currentUser;
  @service dialog;
  @service siteSettings;

  @tracked isAnimated = false;
  @tracked isLoading = false;
  @tracked isWhoActionedVisible = false;
  @tracked actionedUsers = [];
  @tracked totalActionedUsers = 0;

  get actionableCount() {
    return this.args.post.actionable_count || 0;
  }

  get actioned() {
    return !!this.args.post.actioned;
  }

  get canToggle() {
    return !!this.args.post.can_toggle_actionable;
  }

  get disabled() {
    if (this.isLoading) {
      return true;
    }

    // Anonymous users get the login prompt, except where nobody could act.
    if (!this.currentUser) {
      return !!this.args.post.topic?.archived;
    }

    return !this.canToggle;
  }

  get canShowWhoActioned() {
    return !!(
      this.currentUser && this.siteSettings.actionable_show_who_actioned
    );
  }

  get countElementId() {
    return `actionable-count-${this.args.post.id}`;
  }

  get remainingActionedUsers() {
    return Math.max(0, this.totalActionedUsers - this.actionedUsers.length);
  }

  get title() {
    if (this.actioned && !this.canToggle) {
      return "post.controls.has_actioned";
    }

    return this.actioned
      ? "post.controls.undo_actionable"
      : "post.controls.actionable";
  }

  get countTitle() {
    const count = this.actionableCount;

    if (!this.actioned) {
      return i18n("post.has_actionables_title", { count });
    }

    return count === 1
      ? i18n("post.has_actionables_title_only_you")
      : i18n("post.has_actionables_title_you", { count: count - 1 });
  }

  @action
  toggleActionable() {
    if (!this.currentUser) {
      this.args.buttonActions?.showLogin?.();
      return;
    }

    if (this.isLoading) {
      return;
    }

    this.isAnimated = true;
    this.isLoading = true;

    return new Promise((resolve) => {
      discourseLater(async () => {
        this.isAnimated = false;

        try {
          await this.#toggle();
        } finally {
          this.isLoading = false;
          resolve();
        }
      }, 400);
    });
  }

  @action
  async toggleWhoActioned() {
    if (this.isWhoActionedVisible) {
      this.isWhoActionedVisible = false;
      return;
    }

    await this.#loadWhoActioned();
  }

  @action
  closeWhoActioned() {
    this.isWhoActionedVisible = false;
  }

  async #toggle() {
    const post = this.args.post;

    try {
      const result = await ajax(`/actionable/${post.id}`, {
        type: this.actioned ? "DELETE" : "POST",
      });

      post.actionable_count = result.actionable_count;
      post.actioned = result.actioned;
      post.can_toggle_actionable = result.can_toggle_actionable;

      if (this.isWhoActionedVisible) {
        await this.#loadWhoActioned();
      }
    } catch (error) {
      this.dialog.alert(this.#errorMessage(error));
    }
  }

  async #loadWhoActioned() {
    try {
      const result = await ajax(`/actionable/${this.args.post.id}/who`);

      this.actionedUsers = result.users.map(smallUserAttrs);
      this.totalActionedUsers = result.total_count;
      this.isWhoActionedVisible = true;
    } catch (error) {
      this.dialog.alert(this.#errorMessage(error));
    }
  }

  // The server sends user-facing messages; avoid the generic "An error
  // occurred:" prefix that extractError adds to them.
  #errorMessage(error) {
    return error.jqXHR?.responseJSON?.errors?.[0] ?? extractError(error);
  }

  <template>
    <div class="double-button">
      {{#if @post.show_actionable}}
        <div
          class={{dConcatClass
            "discourse-actionable-button"
            (if this.disabled "my-post")
          }}
        >
          {{#if this.actionableCount}}
            <ActionableCount
              ...attributes
              @actioned={{this.actioned}}
              @clickable={{this.canShowWhoActioned}}
              @count={{this.actionableCount}}
              @elementId={{this.countElementId}}
              @expanded={{this.isWhoActionedVisible}}
              @onClick={{this.toggleWhoActioned}}
              @title={{this.countTitle}}
            />
          {{/if}}
          <DButton
            class={{dConcatClass
              "post-action-menu__actionable"
              "toggle-actionable"
              "btn-icon"
              (if this.isAnimated "check-animation")
              (if this.actioned "has-actionable" "actionable")
              (if this.actioned "actionable-by-me")
              (if this.isLoading "loading")
            }}
            ...attributes
            data-post-id={{@post.id}}
            @action={{this.toggleActionable}}
            @ariaLabel={{this.title}}
            @disabled={{this.disabled}}
            @icon="bullseye"
            @title={{this.title}}
          />
        </div>
      {{else if this.actionableCount}}
        <ActionableCount
          ...attributes
          @actioned={{this.actioned}}
          @clickable={{this.canShowWhoActioned}}
          @count={{this.actionableCount}}
          @elementId={{this.countElementId}}
          @expanded={{this.isWhoActionedVisible}}
          @onClick={{this.toggleWhoActioned}}
          @title={{this.countTitle}}
        />
      {{/if}}

      {{#if this.actionableCount}}
        <DSmallUserList
          class="who-actioned"
          @addSelf={{and this.actioned (eq this.remainingActionedUsers 0)}}
          @count={{if
            this.remainingActionedUsers
            this.remainingActionedUsers
            this.totalActionedUsers
          }}
          @description={{if
            this.remainingActionedUsers
            "post.actions.people.actionable_capped"
            "post.actions.people.actionable"
          }}
          @isVisible={{this.isWhoActionedVisible}}
          @users={{this.actionedUsers}}
          {{(if
            this.isWhoActionedVisible
            (modifier
              dCloseOnClickOutside
              this.closeWhoActioned
              (hash targetSelector=(concat "#" this.countElementId))
            )
          )}}
        />
      {{/if}}
    </div>
  </template>
}
