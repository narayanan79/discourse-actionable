import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import SmallUserList, { smallUserAttrs } from "discourse/components/small-user-list";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import closeOnClickOutside from "discourse/modifiers/close-on-click-outside";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import discourseLater from "discourse/lib/later";
import { i18n } from "discourse-i18n";
import { and, eq, not } from "truth-helpers";

/**
 * Actionable button component for marking posts as actionable/requiring action.
 * Displays a toggle button with count and user avatars showing who has actioned the post.
 *
 * @component ActionableButton
 */
export default class ActionableButton extends Component {
  /**
   * Determines if the component should render based on post properties.
   *
   * @param {Object} args - Component arguments
   * @param {Object} args.post - The post object
   * @returns {boolean} True if the button should be rendered
   */
  static shouldRender(args) {
    return args.post.show_actionable || args.post.actionable_count > 0;
  }

  @service currentUser;
  @service messageBus;
  @service dialog;

  /** @type {boolean} Tracks animation state for button click feedback */
  @tracked isAnimated = false;

  /** @type {boolean} Tracks loading state during API calls */
  @tracked isLoading = false;

  /** @type {boolean} Controls visibility of the "who actioned" user list */
  @tracked isWhoActionedVisible = false;

  /** @type {Array} Array of users who have actioned this post */
  @tracked actionedUsers = [];

  /** @type {number} Total count of users who actioned (may exceed displayed users) */
  @tracked totalActionedUsers = 0;

  /** @type {boolean|null} Local override for actioned state during transitions */
  @tracked localActioned = null;

  /** @type {boolean|null} Local override for can_toggle state during transitions */
  @tracked localCanToggleActionable = null;

  /** @type {number|null} Local override for actionable count during transitions */
  @tracked localActionableCount = null;

  constructor() {
    super(...arguments);
    // Bind the callback to maintain 'this' context
    this.boundOnPostUpdate = this.onPostUpdate.bind(this);
    this.subscribeToUpdates();
  }

  willDestroy() {
    super.willDestroy();
    this.unsubscribeFromUpdates();
  }

  /**
   * Gets the actioned state, preferring local override during loading.
   *
   * @returns {boolean} Whether the current user has actioned this post
   */
  get actioned() {
    // During loading, preserve the visual state by using local override
    return this.localActioned !== null ? this.localActioned : this.args.post.actioned;
  }

  /**
   * Gets whether the user can toggle the actionable state.
   *
   * @returns {boolean} Whether the toggle action is allowed
   */
  get canToggleActionable() {
    return this.localCanToggleActionable !== null ? this.localCanToggleActionable : this.args.post.can_toggle_actionable;
  }

  /**
   * Gets the total actionable count for this post.
   *
   * @returns {number} Number of users who have actioned this post
   */
  get actionableCount() {
    return this.localActionableCount !== null ? this.localActionableCount : this.args.post.actionable_count;
  }

  /**
   * Determines if the button should be disabled.
   *
   * @returns {boolean} True if user is logged in but cannot toggle
   */
  get disabled() {
    return this.currentUser && !this.canToggleActionable;
  }

  /**
   * Determines if the button is currently disabled (including loading state).
   *
   * @returns {boolean} True if disabled or loading
   */
  get isDisabled() {
    return this.disabled || this.isLoading;
  }

  /**
   * Subscribes to MessageBus updates for real-time actionable changes.
   */
  subscribeToUpdates() {
    if (!this.messageBus || !this.args.post || !this.args.post.topic) return;

    const channelName = `/topic/${this.args.post.topic.id}`;
    this._channelName = channelName;

    this.messageBus.subscribe(
      channelName,
      this.boundOnPostUpdate
    );
  }

  /**
   * Unsubscribes from MessageBus updates when component is destroyed.
   */
  unsubscribeFromUpdates() {
    if (!this.messageBus || !this._channelName) return;

    this.messageBus.unsubscribe(this._channelName, this.boundOnPostUpdate);
  }

  /**
   * Handles real-time post updates from MessageBus.
   *
   * @param {Object} data - Update data from MessageBus
   */
  onPostUpdate(data) {
    if (!data || !this.args || !this.args.post) {
      return;
    }

    // Only handle updates for this specific post
    if (data.id !== this.args.post.id) {
      return;
    }

      // Handle actionable updates (mirror Like behavior)
      if ((data.type === 'actioned' || data.type === 'unactioned') && data.actionable_count !== undefined) {
      this.args.post.actionable_count = data.actionable_count;
      
      // Update the actioned state for the current user, but NOT during loading
      // This prevents visual flicker during API calls
      if (data.actioned_by === this.currentUser?.id && !this.isLoading) {
        const isActioned = data.type === 'actioned';
        this.args.post.actioned = isActioned;
        // Note: can_toggle_actionable will be updated via server response
        // when user performs action, not through MessageBus
      }
      
      // For other users' actions, we only update the count
      // The current user's actioned state remains unchanged
    }
  }

  /**
   * Gets the title/tooltip for the actionable button.
   *
   * @returns {string} Translation key for the button title
   */
  get title() {
    // If the user has already actioned the post and doesn't have permission
    // to undo that operation, then indicate via the title that they've actioned it
    // and disable the button. Otherwise, set the title even if the user
    // is anonymous (meaning they don't currently have permission to actionable);
    // this is important for accessibility.

    if (this.actioned && !this.canToggleActionable) {
      return "post.controls.has_actioned";
    }

    return this.actioned
      ? "post.controls.undo_actionable"
      : "post.controls.actionable";
  }

  /**
   * Toggles the actionable state for the current post.
   * Handles optimistic UI updates and API communication.
   */
  @action
  async toggleActionable() {
    if (this.isLoading) {
      return;
    }

    // Capture current state before any changes
    const wasActioned = this.actioned;
    const currentCanToggle = this.canToggleActionable;
    const currentCount = this.actionableCount;

    // Immediately set local state to freeze the visual appearance
    // This prevents ANY external updates from changing the UI during loading
    this.localActioned = wasActioned;
    this.localCanToggleActionable = currentCanToggle;
    this.localActionableCount = currentCount;

    this.isAnimated = true;
    this.isLoading = true;

    return new Promise((resolve) => {
      discourseLater(async () => {
        this.isAnimated = false;

        try {
          let response;
          if (wasActioned) {
            response = await ajax(`/actionable/${this.args.post.id}`, {
              type: "DELETE"
            });
          } else {
            response = await ajax(`/actionable/${this.args.post.id}`, {
              type: "POST"
            });
          }

          if (response.success) {
            // Now update to the new state based on API response
            this.localActionableCount = response.actionable_count;
            // Handle both old and new response formats
            this.localActioned = response.actioned !== undefined ? response.actioned : response.acted;
            // Handle both old and new property names for backward compatibility
            this.localCanToggleActionable = response.can_toggle_actionable || response.can_undo_actionable;

            // Also update post properties for other components
            this.args.post.actionable_count = response.actionable_count;
            // Update post actioned state after API response
            this.args.post.actioned = this.localActioned;
            
            // Refresh avatar list if visible
            if (this.isWhoActionedVisible) {
              await this.fetchWhoActioned();
            }
          }
        } catch (error) {
          // On error, reset local state to let post state show through
          this.localActioned = null;
          this.localCanToggleActionable = null;
          this.localActionableCount = null;

          // Extract error message directly from response to avoid "An error occurred:" prefix
          let errorMessage = extractError(error);
          if (error.jqXHR?.responseJSON?.errors) {
            errorMessage = error.jqXHR.responseJSON.errors[0];
          }
          this.dialog.alert(errorMessage);
        } finally {
          this.isLoading = false;
          resolve();
        }
      }, 400);
    });
  }

  /**
   * Calculates how many additional users actioned beyond those shown.
   *
   * @returns {number} Number of remaining users not displayed
   */
  get remainingActionedUsers() {
    return Math.max(0, (this.totalActionedUsers || 0) - (this.actionedUsers?.length || 0));
  }

  /**
   * Toggles the visibility of the "who actioned" user list.
   */
  @action
  async toggleWhoActioned() {
    if (this.isWhoActionedVisible) {
      this.isWhoActionedVisible = false;
      return;
    }

    await this.fetchWhoActioned();
  }

  /**
   * Closes the "who actioned" user list.
   */
  @action
  closeWhoActioned() {
    this.isWhoActionedVisible = false;
  }

  /**
   * Fetches the list of users who have actioned this post from the API.
   */
  async fetchWhoActioned() {
    try {
      const response = await ajax(`/actionable/${this.args.post.id}/who`);

      this.actionedUsers = response.users.map(smallUserAttrs);
      this.totalActionedUsers = response.total_count;
      this.isWhoActionedVisible = true;
    } catch (error) {
      this.dialog.alert(extractError(error));
    }
  }

  <template>
    {{#if @post.show_actionable}}
      <div class="double-button">
        <div
          class={{concatClass
            "discourse-actionable-button"
            (if this.disabled "my-post")
          }}
        >
          <ActionableCount
            ...attributes
            @post={{@post}}
            @actioned={{this.actioned}}
            @actionableCount={{this.actionableCount}}
            @action={{this.toggleWhoActioned}}
            @isWhoActionedVisible={{this.isWhoActionedVisible}}
          />
          <DButton
            class={{concatClass
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
            disabled={{this.isDisabled}}
            @action={{this.toggleActionable}}
            @icon="bullseye"
            @title={{this.title}}
          />
        </div>
        {{#if this.actionableCount}}
          <SmallUserList
            class="who-actioned"
            @addSelf={{and this.actioned (eq this.remainingActionedUsers 0)}}
            @isVisible={{this.isWhoActionedVisible}}
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
            @users={{this.actionedUsers}}
            {{(if
              this.isWhoActionedVisible
              (modifier
                closeOnClickOutside
                (fn this.closeWhoActioned)
                (hash targetSelector=".actionable-count")
              )
            )}}
          />
        {{/if}}
      </div>
    {{else}}
      <div class="double-button">
        <ActionableCount
          ...attributes
          @post={{@post}}
          @actioned={{this.actioned}}
          @actionableCount={{this.actionableCount}}
          @action={{this.toggleWhoActioned}}
          @isWhoActionedVisible={{this.isWhoActionedVisible}}
        />
        {{#if this.actionableCount}}
          <SmallUserList
            class="who-actioned"
            @addSelf={{and this.actioned (eq this.remainingActionedUsers 0)}}
            @isVisible={{this.isWhoActionedVisible}}
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
            @users={{this.actionedUsers}}
            {{(if
              this.isWhoActionedVisible
              (modifier
                closeOnClickOutside
                (fn this.closeWhoActioned)
                (hash targetSelector=".actionable-count")
              )
            )}}
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}

/**
 * Displays the count of actionable actions on a post.
 * Shows a clickable count that opens the user list when clicked.
 *
 * @component ActionableCount
 */
class ActionableCount extends Component {
  @service siteSettings;

  // No icon in count - only show the number like the like button

  /**
   * Gets the actioned state from args or post.
   *
   * @returns {boolean} Whether the current user has actioned this post
   */
  get actioned() {
    return this.args.actioned !== undefined ? this.args.actioned : this.args.post.actioned;
  }

  /**
   * Gets the actionable count from args or post.
   *
   * @returns {number} Total number of actionable actions
   */
  get actionableCount() {
    return this.args.actionableCount !== undefined ? this.args.actionableCount : this.args.post.actionable_count;
  }

  /**
   * Checks if the "who actioned" feature is enabled.
   *
   * @returns {boolean} Whether users can click to see who actioned
   */
  get canShowWhoActioned() {
    return this.siteSettings.actionable_show_who_actioned;
  }

  /**
   * Generates the translated title/tooltip for the count display.
   *
   * @returns {string} Translated title text
   */
  get translatedTitle() {
    let title;

    if (this.actioned) {
      title =
        this.actionableCount === 1
          ? "post.has_actionables_title_only_you"
          : "post.has_actionables_title_you";
    } else {
      title = "post.has_actionables_title";
    }

    return i18n(title, {
      count: this.actioned
        ? this.actionableCount - 1
        : this.actionableCount,
    });
  }

  /**
   * Handles click on the count to toggle the user list.
   * Only works if actionable_show_who_actioned setting is enabled.
   */
  @action
  toggleWhoActioned() {
    // Don't do anything if the setting is disabled
    if (!this.canShowWhoActioned) {
      return;
    }

    if (this.args.action) {
      this.args.action();
    }
  }

  <template>
    {{#if this.actionableCount}}
      <button
        class={{concatClass
          "post-action-menu__actionable-count"
          "actionable-count"
          "button-count"
          "highlight-action"
          (if this.actioned "my-actionables" "regular-actionables")
          (if (not this.canShowWhoActioned) "who-actioned-disabled")
        }}
        ...attributes
        title={{this.translatedTitle}}
        {{(if this.canShowWhoActioned (modifier on "click" this.toggleWhoActioned))}}
        type="button"
        aria-pressed={{@isWhoActionedVisible}}
        disabled={{not this.canShowWhoActioned}}
      >
        {{this.actionableCount}}
      </button>
    {{/if}}
  </template>
}