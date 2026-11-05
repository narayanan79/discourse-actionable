# frozen_string_literal: true

# Marks a post as actionable for the acting user.
#
# Writes (post action, user actions + stats, daily count, post counter) happen
# in one transaction. `lock(:post_id)` serializes marks of the same post so the
# "already actioned" check holds; the recount also takes the post row lock, which
# orders it against a concurrent unmark (ActionableActionDestroyer). Cache
# invalidation, MessageBus and the `:actionable_created` event run after commit.
class ActionableActionCreator
  include Service::Base

  params do
    attribute :post_id, :integer

    validates :post_id, presence: true
  end

  model :post
  policy :can_mark_post_actionable

  lock(:post_id) do
    policy :not_already_actioned

    transaction do
      step :create_post_action
      step :log_user_actions
      step :track_daily_count
      step :update_post_actionable_count
    end
  end

  step :invalidate_user_summaries
  step :publish_post_change
  step :trigger_event

  private

  def fetch_post(params:)
    Post.find_by(id: params.post_id)
  end

  def can_mark_post_actionable(guardian:, post:)
    guardian.can_mark_post_actionable?(post)
  end

  def not_already_actioned(guardian:, post:)
    type_id = DiscourseActionable::POST_ACTION_TYPE_ID
    !PostAction.exists?(post_id: post.id, user_id: guardian.user.id, post_action_type_id: type_id)
  end

  def create_post_action(guardian:, post:)
    type_id = DiscourseActionable::POST_ACTION_TYPE_ID
    result = PostActionCreator.new(guardian.user, post, type_id, silent: true).perform

    if result.failed? || result.post_action.blank?
      fail!(result.errors.full_messages.join(", ").presence || "post action was not created")
    end

    # Exposed to later steps, the success handler and the event listeners.
    context[:post_action] = result.post_action
  end

  def log_user_actions(guardian:, post:)
    acting_user_id = guardian.user.id
    given_type = DiscourseActionable::USER_ACTION_GIVEN
    received_type = DiscourseActionable::USER_ACTION_RECEIVED
    shared = { acting_user_id:, target_post_id: post.id, target_topic_id: post.topic_id }

    # log_action! also increments user_stats (except in private messages).
    UserAction.log_action!(shared.merge(action_type: given_type, user_id: acting_user_id))
    UserAction.log_action!(shared.merge(action_type: received_type, user_id: post.user_id))
  end

  # Keyed by the action's own date so the destroyer decrements the same row.
  def track_daily_count(guardian:, post_action:)
    ActionableDaily.increment_for(guardian.user.id, post_action.created_at.to_date)
  end

  def update_post_actionable_count(post:)
    post.update_actionable_count
  end

  def invalidate_user_summaries(guardian:, post:)
    ActionableCacheHelper.invalidate_user_summary_cache(guardian.user.id, post.user_id)
  end

  def publish_post_change(guardian:, post:)
    payload = { actionable_count: post.actionable_count, skip_topic_stats: true }
    # Who marked a post is only public when the site shows it.
    payload[:actioned_by] = guardian.user.id if SiteSetting.actionable_show_who_actioned
    post.publish_change_to_clients!(:actioned, payload)
  end

  def trigger_event(guardian:, post_action:)
    DiscourseEvent.trigger(:actionable_created, post_action, guardian.user)
  end
end
