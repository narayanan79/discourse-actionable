# frozen_string_literal: true

class ActionableActionDestroyer
  include Service::Base

  params do
    attribute :post_id, :integer

    validates :post_id, presence: true
  end

  model :post
  model :post_action
  policy :can_remove_action
  step :destroy_action
  step :update_post_data
  step :log_action

  private

  def fetch_post(params:)
    Post.find_by(id: params.post_id)
  end

  def fetch_post_action(guardian:, post:)
    actionable_type_id = PostActionType.find_by(name_key: "actionable")&.id
    PostAction.find_by(post: post, user: guardian.user, post_action_type_id: actionable_type_id)
  end

  def can_remove_action(guardian:, post:, post_action:)
    return false unless post_action
    return false unless guardian.can_delete_post_action?(post_action)
    return false if post_action.deleted_at.present?
    # Allow undo at any time, like Like
    true
  end

  def destroy_action(post_action:, guardian:, post:)
    @destroyed_action = post_action

    # Soft delete the action
    post_action.remove_act!(guardian.user)

    # Decrement daily count
    ActionableDaily.decrement_for(guardian.user.id)

    # Invalidate user summary cache to ensure stats show up immediately
    giver_cache_key = "user_summary:#{guardian.user.id}:#{guardian.user.id}"
    receiver_cache_key = "user_summary:#{post.user.id}:#{post.user.id}"
    public_giver_cache_key = "user_summary:#{guardian.user.id}:0"
    public_receiver_cache_key = "user_summary:#{post.user.id}:0"

    Discourse.cache.delete(giver_cache_key)
    Discourse.cache.delete(receiver_cache_key)
    Discourse.cache.delete(public_giver_cache_key)
    Discourse.cache.delete(public_receiver_cache_key)

    # Note: UserAction records are removed by the :post_action_destroyed event listener in plugin.rb
    # to avoid duplication and maintain single source of truth

    true
  rescue => e
    Rails.logger.error("Failed to destroy actionable action: #{e.message}")
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
      Rails.logger.info(
        "Staff user #{guardian.user.username} removed actionable from post #{post.id}",
      )
    end

    DiscourseEvent.trigger(:actionable_destroyed, @destroyed_action, guardian.user)
  end
end
