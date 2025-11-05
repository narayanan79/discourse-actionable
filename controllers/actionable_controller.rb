# frozen_string_literal: true

class ActionableController < ApplicationController
  requires_login
  before_action :ensure_actionable_enabled

  def create
    ActionableActionCreator.call(service_params) do
      on_success do |post:|
        # Reload to get fresh serializer data
        post.reload
        serializer = PostSerializer.new(post, scope: guardian, root: false)

        render json: {
                 success: true,
                 actionable_count: post.actionable_count || 0,
                 acted: true,
                 actioned: serializer.actioned,
                 can_toggle_actionable: serializer.can_toggle_actionable,
               }
      end

      on_failure do
        render json: {
                 success: false,
                 errors: ["Failed to mark as actionable"],
               },
               status: :unprocessable_entity
      end

      on_failed_policy(:can_create_actionable) do |policy|
        render json: {
                 success: false,
                 errors: ["Not allowed to mark as actionable"],
               },
               status: :forbidden
      end

      on_failed_policy(:within_rate_limit) do |policy|
        render json: { success: false, errors: ["Rate limit exceeded"] }, status: :too_many_requests
      end

      on_model_not_found(:post) do
        render json: { success: false, errors: ["Post not found"] }, status: :not_found
      end

      on_failed_contract do |contract|
        render json: { success: false, errors: contract.errors.full_messages }, status: :bad_request
      end
    end
  end

  def destroy
    ActionableActionDestroyer.call(service_params) do
      on_success do |post:|
        # Reload to get fresh serializer data
        post.reload
        serializer = PostSerializer.new(post, scope: guardian, root: false)

        render json: {
                 success: true,
                 actionable_count: post.actionable_count || 0,
                 acted: false,
                 actioned: serializer.actioned,
                 can_toggle_actionable: serializer.can_toggle_actionable,
               }
      end

      on_failure do
        render json: {
                 success: false,
                 errors: ["Failed to unmark as actionable"],
               },
               status: :unprocessable_entity
      end

      on_failed_policy(:can_remove_action) do |policy|
        render json: {
                 success: false,
                 errors: [
                   "The Actionable reaction was created too long ago. It can no longer be modified or removed.",
                 ],
               },
               status: :forbidden
      end

      on_model_not_found(:post) do
        render json: { success: false, errors: ["Post not found"] }, status: :not_found
      end

      on_failed_contract do |contract|
        render json: { success: false, errors: contract.errors.full_messages }, status: :bad_request
      end
    end
  end

  def who_actioned
    params.require(:post_id)

    post = Post.find(params[:post_id])
    guardian.ensure_can_see!(post)

    raise Discourse::InvalidAccess unless SiteSetting.actionable_show_who_actioned

    actionable_type_id = PostActionType.find_by(name_key: "actionable")&.id
    actions =
      PostAction
        .includes(:user)
        .where(post: post, post_action_type_id: actionable_type_id)
        .where(deleted_at: nil)
        .limit(50)

    users = actions.map(&:user).compact.uniq

    render json: {
             users:
               ActiveModel::ArraySerializer.new(
                 users,
                 each_serializer: BasicUserSerializer,
               ).as_json,
             total_count: actions.count,
           }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Post not found" }, status: :not_found
  end

  private

  def service_params
    { params: params.to_unsafe_h, guardian: guardian }
  end

  def ensure_actionable_enabled
    raise Discourse::NotFound unless SiteSetting.actionable_enabled
  end
end
