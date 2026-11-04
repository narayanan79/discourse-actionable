# frozen_string_literal: true

class ActionableController < ApplicationController
  WHO_ACTIONED_LIMIT = 50

  requires_plugin DiscourseActionable::PLUGIN_NAME
  requires_login

  before_action :ensure_daily_limit_not_reached, only: :create

  def create
    ActionableActionCreator.call(service_params) do
      on_success do |post:|
        # Only successful marks count towards the daily limit.
        daily_rate_limiter.performed!(raise_error: false)
        render_toggle_result(post)
      end
      on_failed_contract do |contract|
        render_errors(contract.errors.full_messages, status: :bad_request)
      end
      on_model_not_found(:post) { render_error(:post_not_found, status: :not_found) }
      on_failed_policy(:can_mark_post_actionable) { render_error(:not_allowed, status: :forbidden) }
      on_failed_policy(:not_already_actioned) do
        render_error(:already_actioned, status: :unprocessable_entity)
      end
      on_lock_not_acquired(:post_id) { raise Discourse::ReadOnly }
      on_failure { render_error(:create_failed, status: :unprocessable_entity) }
    end
  end

  def destroy
    ActionableActionDestroyer.call(service_params) do
      on_success { |post:| render_toggle_result(post) }
      on_failed_contract do |contract|
        render_errors(contract.errors.full_messages, status: :bad_request)
      end
      on_model_not_found(:post) { render_error(:post_not_found, status: :not_found) }
      on_model_not_found(:post_action) { render_error(:not_actioned, status: :not_found) }
      on_failed_policy(:can_remove_post_action) { render_error(:timeout, status: :forbidden) }
      on_lock_not_acquired(:post_id) { raise Discourse::ReadOnly }
      on_failure { render_error(:destroy_failed, status: :unprocessable_entity) }
    end
  end

  def who_actioned
    post = Post.find_by(id: params[:post_id])
    raise Discourse::NotFound if post.blank?
    guardian.ensure_can_see!(post)
    raise Discourse::InvalidAccess if !SiteSetting.actionable_show_who_actioned

    type_id = DiscourseActionable::POST_ACTION_TYPE_ID
    post_actions = PostAction.where(post_id: post.id, post_action_type_id: type_id)
    # Same rule as core's "who liked" list: hide users the viewer ignores.
    post_actions = post_actions.where(<<~SQL, current_user_id: current_user.id)
      NOT EXISTS (
        SELECT 1 FROM ignored_users ig
        WHERE ig.user_id = :current_user_id
          AND ig.ignored_user_id = post_actions.user_id
          AND ig.ignored_user_id <> :current_user_id
      )
    SQL

    total_count = post_actions.count
    ordered = post_actions.includes(:user).order(:created_at, :id)
    users = ordered.limit(WHO_ACTIONED_LIMIT).filter_map(&:user)

    render json: { users: serialize_data(users, BasicUserSerializer), total_count: total_count }
  end

  private

  def daily_rate_limiter
    @daily_rate_limiter ||=
      RateLimiter.new(current_user, "actionable", SiteSetting.actionable_max_per_day, 1.day)
  end

  # Raises RateLimiter::LimitExceeded (rendered as a 429 with the wait time)
  # without consuming a slot; the slot is recorded only on success.
  def ensure_daily_limit_not_reached
    if SiteSetting.actionable_max_per_day <= 0
      # A limit of 0 turns marking off for everyone except staff.
      render_error(:not_allowed, status: :forbidden) if !current_user.staff?
      return
    end

    daily_rate_limiter.performed! if !daily_rate_limiter.can_perform?
  end

  def render_toggle_result(post)
    post.reload
    serializer = PostSerializer.new(post, scope: guardian, root: false)
    actioned = serializer.actioned

    # `acted` is kept for clients written against earlier versions.
    payload = {
      success: true,
      actionable_count: post.actionable_count,
      acted: actioned,
      actioned: actioned,
      can_toggle_actionable: serializer.can_toggle_actionable,
      can_undo_actionable: serializer.can_undo_actionable,
    }

    render json: payload
  end

  def render_error(key, status:)
    render_errors([I18n.t("actionable.errors.#{key}")], status: status)
  end

  def render_errors(messages, status:)
    render json: { success: false, errors: messages }, status: status
  end
end
