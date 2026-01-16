# frozen_string_literal: true

# name: discourse-actionable
# about: Adds an actionable button next to the like button, allowing users to mark posts as actionable
# version: 1.0.0
# authors: Discourse Team
# url: https://github.com/narayanan79/discourse-actionable
# required_version: 3.5

enabled_site_setting :actionable_enabled

# Register stylesheet
register_asset "stylesheets/actionable.scss"

# Register custom SVG icons
register_svg_icon "bullseye"

after_initialize do
  # Require controller
  require_relative "controllers/actionable_controller.rb"

  # Add routes
  Discourse::Application.routes.append do
    post "/actionable/:post_id" => "actionable#create"
    delete "/actionable/:post_id" => "actionable#destroy"
    get "/actionable/:post_id/who" => "actionable#who_actioned"
  end

  require_relative "lib/actionable_cache_helper.rb"
  require_relative "lib/actionable_daily.rb"
  require_relative "lib/actionable_action_creator.rb"
  require_relative "lib/actionable_action_destroyer.rb"

  # Add UserAction constants for actionable actions
  reloadable_patch do |plugin|
    UserAction::ACTIONABLE_GIVEN = 18 unless UserAction.const_defined?(:ACTIONABLE_GIVEN)
    UserAction::ACTIONABLE_RECEIVED = 19 unless UserAction.const_defined?(:ACTIONABLE_RECEIVED)
  end

  # Add post action type for actionable using reloadable_patch
  reloadable_patch { |plugin| PostActionType.types[:actionable] = 50 }

  PostActionType.seed do |pat|
    pat.id = 50
    pat.name_key = "actionable"
    pat.is_flag = false
    pat.icon = "bullseye"
    pat.position = 3
  end

  # Add actionable action summary (following like button pattern)
  add_to_serializer(:post, :actionable_count) { object.actionable_count || 0 }

  add_to_serializer(:post, :actioned) do
    return false unless scope.user
    actionable_type_id = PostActionType.find_by(name_key: "actionable")&.id
    PostAction.exists?(
      post: object,
      user: scope.user,
      post_action_type_id: actionable_type_id,
      deleted_at: nil,
    )
  end

  add_to_serializer(:post, :can_undo_actionable) do
    return false unless scope.user
    return false unless SiteSetting.actionable_enabled

    actionable_type_id = PostActionType.find_by(name_key: "actionable")&.id
    PostAction.exists?(
      post: object,
      user: scope.user,
      post_action_type_id: actionable_type_id,
      deleted_at: nil,
    )
  end

  add_to_serializer(:post, :can_toggle_actionable) do
    return false unless scope.user
    return false unless SiteSetting.actionable_enabled
    return false if object.user == scope.user
    return false if object.trashed?
    return false if object.topic.archived?

    # Check basic permission first
    return false if scope.user.trust_level < SiteSetting.actionable_min_trust_level

    # Check if user has already actioned this post
    actionable_type_id = PostActionType.find_by(name_key: "actionable")&.id
    return false unless actionable_type_id

    existing_action =
      PostAction.find_by(
        post: object,
        user: scope.user,
        post_action_type_id: actionable_type_id,
        deleted_at: nil,
      )

    if existing_action
      # User has already actioned - check if they can undo (within timeout)
      scope.can_delete_post_action?(existing_action)
    else
      # User hasn't actioned - they can act if they meet basic requirements
      true
    end
  end

  add_to_serializer(:post, :show_actionable) { SiteSetting.actionable_enabled }

  # Track actionable stats
  add_to_class(:post, :update_actionable_count) do
    actionable_type_id = PostActionType.find_by(name_key: "actionable")&.id
    count = post_actions.where(post_action_type_id: actionable_type_id, deleted_at: nil).count
    update_column(:actionable_count, count)
  end

  # Event listeners for actionable actions - only handle MessageBus publishing
  # User stats and UserAction logging is handled by PostActionCreator and the extension below
  on(:actionable_created) do |post_action, creator|
    if post_action && creator
      post = post_action.post
      # Publish real-time update using Discourse's standard method
      post.publish_change_to_clients!(
        :actioned,
        { actionable_count: post.actionable_count, actioned_by: creator.id },
      )
    end
  end

  on(:actionable_destroyed) do |post_action, destroyer|
    if post_action && destroyer
      post = post_action.post
      # Publish real-time update using Discourse's standard method
      post.publish_change_to_clients!(
        :unactioned,
        { actionable_count: post.actionable_count, actioned_by: destroyer.id },
      )
    end
  end

  # Extend UserAction.update_like_count to handle actionable stats
  reloadable_patch do |plugin|
    module UserActionActionableExtension
      def update_like_count(user_id, action_type, delta)
        if action_type == UserAction::LIKE
          UserStat.where(user_id: user_id).update_all("likes_given = likes_given + #{delta.to_i}")
        elsif action_type == UserAction::WAS_LIKED
          UserStat.where(user_id: user_id).update_all(
            "likes_received = likes_received + #{delta.to_i}",
          )
        elsif action_type == UserAction::ACTIONABLE_GIVEN
          UserStat.where(user_id: user_id).update_all(
            "actionable_given = actionable_given + #{delta.to_i}",
          )
        elsif action_type == UserAction::ACTIONABLE_RECEIVED
          UserStat.where(user_id: user_id).update_all(
            "actionable_received = actionable_received + #{delta.to_i}",
          )
        else
          super
        end
      end
    end

    UserAction.singleton_class.prepend(UserActionActionableExtension)
  end

  # No global ratelimiter instance; service layer enforces per-user daily limits

  # Automatically enable/disable directory columns based on site setting
  on(:site_setting_changed) do |setting_name, old_value, new_value|
    if setting_name == :actionable_enabled
      DirectoryColumn.where(name: %w[actionable_given actionable_received]).update_all(
        enabled: new_value,
      )
    end
  end

  # Initialize directory columns enabled state based on current site setting
  on(:before_directory_refresh) do
    DirectoryColumn.where(name: %w[actionable_given actionable_received]).update_all(
      enabled: SiteSetting.actionable_enabled,
    )
  end

  # Also sync columns when the plugin loads
  reloadable_patch do |plugin|
    Rails.application.config.to_prepare do
      DirectoryColumn.where(name: %w[actionable_given actionable_received]).update_all(
        enabled: SiteSetting.actionable_enabled,
      )
    end
  end

  # Add plugin directory columns for actionable stats
  add_directory_column("actionable_received", icon: "bullseye", query: <<~SQL)
      WITH actionable_stats AS (
        SELECT
          u.id AS user_id,
          COUNT(CASE WHEN ua.action_type = #{UserAction::ACTIONABLE_RECEIVED} AND ua.created_at > :since THEN 1 END) AS actionable_received_count
        FROM users u
        LEFT JOIN user_actions ua ON ua.user_id = u.id AND ua.created_at > :since
        WHERE u.active AND u.silenced_till IS NULL AND u.id > 0
        GROUP BY u.id
      )
      UPDATE directory_items di
      SET actionable_received = actionable_stats.actionable_received_count
      FROM actionable_stats
      WHERE actionable_stats.user_id = di.user_id
        AND di.period_type = :period_type
        AND di.actionable_received <> actionable_stats.actionable_received_count
    SQL

  add_directory_column("actionable_given", icon: "bullseye", query: <<~SQL)
      WITH actionable_stats AS (
        SELECT
          u.id AS user_id,
          COUNT(CASE WHEN ua.action_type = #{UserAction::ACTIONABLE_GIVEN} AND ua.created_at > :since THEN 1 END) AS actionable_given_count
        FROM users u
        LEFT JOIN user_actions ua ON ua.user_id = u.id AND ua.created_at > :since
        WHERE u.active AND u.silenced_till IS NULL AND u.id > 0
        GROUP BY u.id
      )
      UPDATE directory_items di
      SET actionable_given = actionable_stats.actionable_given_count
      FROM actionable_stats
      WHERE actionable_stats.user_id = di.user_id
        AND di.period_type = :period_type
        AND di.actionable_given <> actionable_stats.actionable_given_count
    SQL

  # Scheduled job to clean up old daily tracking records
  # Runs once per day at midnight to remove records older than 90 days
  every :day, at: 0.hours do
    ActionableDaily.cleanup_old_records(90)
  end
end
