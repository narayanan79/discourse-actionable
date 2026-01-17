# frozen_string_literal: true

class ActionableActionCreator
  include Service::Base

  params do
    attribute :post_id, :integer

    validates :post_id, presence: true
  end

  model :post
  policy :can_create_actionable
  policy :within_rate_limit
  step :create_action
  step :update_post_data
  step :log_action

  private

  def fetch_post(params:)
    Post.find_by(id: params.post_id)
  end

  def can_create_actionable(guardian:, post:)
    return false unless SiteSetting.actionable_enabled
    return false unless guardian.user
    return false if guardian.user.trust_level < SiteSetting.actionable_min_trust_level
    return false if post.user == guardian.user # Can't action your own posts
    return false if post.trashed?
    return false if post.topic.archived?
    return false if post.topic.closed?

    # Check if already actioned
    actionable_type_id = PostActionType.find_by(name_key: "actionable")&.id
    existing_action =
      PostAction.find_by(post: post, user: guardian.user, post_action_type_id: actionable_type_id)

    return false if existing_action && existing_action.deleted_at.nil?

    true
  end

  def within_rate_limit(guardian:)
    RateLimiter.new(
      guardian.user,
      "actionable",
      SiteSetting.actionable_max_per_day,
      1.day,
    ).performed!
    true
  rescue RateLimiter::LimitExceeded
    false
  end

  def create_action(guardian:, post:)
    actionable_type_id = PostActionType.find_by(name_key: "actionable")&.id
    return false unless actionable_type_id

    # Use Discourse's PostActionCreator for robust action creation
    # This automatically handles UserAction logging and event triggering
    creator = PostActionCreator.new(guardian.user, post, actionable_type_id, silent: true)

    result = creator.perform
    @post_action = result.post_action

    return false unless result.success && @post_action

    # Track daily action
    ActionableDaily.increment_for(guardian.user.id)

    # Create UserAction records for both the giver and receiver
    # This is necessary for custom action types as PostActionCreator doesn't do this automatically
    UserAction.log_action!(
      action_type: UserAction::ACTIONABLE_GIVEN,
      user_id: guardian.user.id,
      acting_user_id: guardian.user.id,
      target_post_id: post.id,
      target_topic_id: post.topic_id,
    )

    UserAction.log_action!(
      action_type: UserAction::ACTIONABLE_RECEIVED,
      user_id: post.user.id,
      acting_user_id: guardian.user.id,
      target_post_id: post.id,
      target_topic_id: post.topic_id,
    )

    # Update user stats counters
    # Discourse's log_action! does not call update_like_count, so we must do it manually
    # Our UserActionActionableExtension handles the custom action types
    UserAction.update_like_count(guardian.user.id, UserAction::ACTIONABLE_GIVEN, 1)
    UserAction.update_like_count(post.user.id, UserAction::ACTIONABLE_RECEIVED, 1)

    # Invalidate user summary cache AFTER stats are updated to ensure fresh data
    ActionableCacheHelper.invalidate_user_summary_cache(guardian.user.id, post.user.id)

    true
  rescue => e
    Rails.logger.error("Failed to create actionable action: #{e.message}")
    false
  end

  def update_post_data(post:)
    actionable_type_id = PostActionType.find_by(name_key: "actionable")&.id
    count =
      PostAction.where(post: post, post_action_type_id: actionable_type_id, deleted_at: nil).count

    post.update_column(:actionable_count, count)
  end

  def log_action(guardian:, post:)
    # Log to staff action log if user is staff (simplified)
    if guardian.user.staff?
      Rails.logger.info("Staff user #{guardian.user.username} marked post #{post.id} as actionable")
    end

    DiscourseEvent.trigger(:actionable_created, @post_action, guardian.user)
  end
end
