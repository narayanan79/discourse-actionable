# frozen_string_literal: true

# name: discourse-actionable
# about: Adds an actionable button next to the like button, allowing users to mark posts as actionable
# version: 1.1.0
# authors: narayanan79
# url: https://github.com/narayanan79/discourse-actionable
# required_version: 2026.5.0

enabled_site_setting :actionable_enabled

register_asset "stylesheets/actionable.scss"

register_svg_icon "bullseye"

module ::DiscourseActionable
  PLUGIN_NAME = "discourse-actionable"

  # Persisted identifiers: changing them requires a data migration.
  POST_ACTION_TYPE_ID = 50
  POST_ACTION_TYPE_NAME_KEY = "actionable"
  USER_ACTION_GIVEN = 18
  USER_ACTION_RECEIVED = 19
end

after_initialize do
  require_relative "lib/actionable_cache_helper"
  require_relative "lib/actionable_daily"
  require_relative "lib/directory_columns"
  require_relative "lib/guardian_extension"
  require_relative "lib/post_action_users_controller_extension"
  require_relative "lib/post_actions_controller_extension"
  require_relative "lib/post_serializer_extension"
  require_relative "lib/user_action_extension"
  require_relative "lib/user_summary_extension"
  require_relative "lib/users_controller_extension"
  require_relative "lib/actionable_action_creator"
  require_relative "lib/actionable_action_destroyer"
  require_relative "controllers/actionable_controller"
  require_relative "app/jobs/scheduled/cleanup_actionable_daily"

  register_seedfu_fixtures(File.expand_path("db/fixtures", __dir__))

  Discourse::Application.routes.append do
    constraints(post_id: /\d+/) do
      post "/actionable/:post_id" => "actionable#create"
      delete "/actionable/:post_id" => "actionable#destroy"
      get "/actionable/:post_id/who" => "actionable#who_actioned"
    end
  end

  reloadable_patch do
    ::Guardian.prepend(DiscourseActionable::GuardianExtension)
    ::PostActionUsersController.prepend(DiscourseActionable::PostActionUsersControllerExtension)
    ::PostActionsController.prepend(DiscourseActionable::PostActionsControllerExtension)
    ::PostSerializer.prepend(DiscourseActionable::PostSerializerExtension)
    ::UserAction.singleton_class.prepend(DiscourseActionable::UserActionExtension)
    ::UserSummary.prepend(DiscourseActionable::UserSummaryExtension)
    ::UsersController.prepend(DiscourseActionable::UsersControllerExtension)

    # Kept for code written against earlier versions of the plugin.
    # rubocop:disable Discourse/Plugins/NamespaceConstants
    if !::UserAction.const_defined?(:ACTIONABLE_GIVEN, false)
      ::UserAction::ACTIONABLE_GIVEN = DiscourseActionable::USER_ACTION_GIVEN
    end
    if !::UserAction.const_defined?(:ACTIONABLE_RECEIVED, false)
      ::UserAction::ACTIONABLE_RECEIVED = DiscourseActionable::USER_ACTION_RECEIVED
    end
    # rubocop:enable Discourse/Plugins/NamespaceConstants
  end

  add_to_class(:post, :update_actionable_count) do
    # Row lock first: a concurrent mark and unmark of this post then count one
    # after the other, and the later count sees the other's committed change.
    Post.where(id:).lock.pick(:id)
    type_id = DiscourseActionable::POST_ACTION_TYPE_ID
    count = PostAction.where(post_id: id, post_action_type_id: type_id).count
    update_column(:actionable_count, count)
  end

  # Post serializer: state for the post menu button.
  add_to_serializer(:post, :actionable_count) { object.actionable_count.to_i }
  add_to_serializer(:post, :show_actionable) { SiteSetting.actionable_enabled }
  add_to_serializer(:post, :actioned) { actionable_post_action.present? }

  add_to_serializer(:post, :can_undo_actionable) do
    action = actionable_post_action
    action.present? && scope.can_delete_post_action?(action)
  end

  add_to_serializer(:post, :can_toggle_actionable) do
    action = actionable_post_action
    action ? scope.can_delete_post_action?(action) : scope.can_mark_post_actionable?(object)
  end

  # User summary: stats and "most actionabled" lists. The lists use core's
  # serializer so `enable_names`, flair and staff fields behave like likes.
  can_see_stats = -> { scope.can_see_summary_stats?(object.user) }
  has_givers = -> { object.most_actionabled_by_users.present? }
  has_receivers = -> { object.most_actionabled_users.present? }

  add_to_serializer(:user_summary, :actionable_given, include_condition: can_see_stats) do
    object.actionable_given
  end

  add_to_serializer(:user_summary, :actionable_received, include_condition: can_see_stats) do
    object.actionable_received
  end

  add_to_serializer(:user_summary, :most_actionabled_by_users, include_condition: has_givers) do
    serializer = UserSummarySerializer::UserWithCountSerializer
    users = object.most_actionabled_by_users
    ActiveModel::ArraySerializer.new(users, each_serializer: serializer, scope:).as_json
  end

  add_to_serializer(:user_summary, :most_actionabled_users, include_condition: has_receivers) do
    serializer = UserSummarySerializer::UserWithCountSerializer
    users = object.most_actionabled_users
    ActiveModel::ArraySerializer.new(users, each_serializer: serializer, scope:).as_json
  end

  # Summary pages are cached for an hour per viewer; refresh the ones we can.
  on(:like_created) do |post_action|
    liked_user_id = post_action.post&.user_id
    ActionableCacheHelper.invalidate_user_summary_cache(post_action.user_id, liked_user_id)
  end

  on(:like_destroyed) do |post_action|
    liked_user_id = post_action.post&.user_id
    ActionableCacheHelper.invalidate_user_summary_cache(post_action.user_id, liked_user_id)
  end

  on(:user_destroyed) { |user| ActionableDaily.where(user_id: user.id).delete_all }

  # User directory columns.
  columns = DiscourseActionable::DirectoryColumns
  received_query =
    columns.query(column: columns::RECEIVED, action_type: DiscourseActionable::USER_ACTION_RECEIVED)
  given_query =
    columns.query(column: columns::GIVEN, action_type: DiscourseActionable::USER_ACTION_GIVEN)

  add_directory_column(columns::RECEIVED, icon: "bullseye", query: received_query)
  add_directory_column(columns::GIVEN, icon: "bullseye", query: given_query)

  # Runs when the plugin is switched off too (unlike `on`).
  on_enabled_change { |_old_value, new_value| columns.set_enabled(new_value) }
end
