# frozen_string_literal: true

desc "Backfill UserAction records for existing actionable PostActions"
task "actionable:backfill_user_actions" => :environment do
  puts "Starting backfill of actionable UserAction records..."

  actionable_type_id = PostActionType.find_by(name_key: "actionable")&.id
  unless actionable_type_id
    puts "ERROR: Actionable post action type not found!"
    exit 1
  end

  # Find all existing actionable PostActions
  post_actions =
    PostAction.where(post_action_type_id: actionable_type_id, deleted_at: nil).includes(
      :user,
      post: :topic,
    )

  puts "Found #{post_actions.count} actionable post actions to process"

  created_count = 0
  skipped_count = 0

  post_actions.find_each do |pa|
    # Check if UserAction already exists for giver
    unless UserAction.exists?(
             action_type: UserAction::ACTIONABLE_GIVEN,
             user_id: pa.user_id,
             target_post_id: pa.post_id,
           )
      UserAction.log_action!(
        action_type: UserAction::ACTIONABLE_GIVEN,
        user_id: pa.user_id,
        acting_user_id: pa.user_id,
        target_post_id: pa.post_id,
        target_topic_id: pa.post.topic_id,
        created_at: pa.created_at,
      )
      created_count += 1
      print "."
    else
      skipped_count += 1
    end

    # Check if UserAction already exists for receiver
    unless UserAction.exists?(
             action_type: UserAction::ACTIONABLE_RECEIVED,
             user_id: pa.post.user_id,
             target_post_id: pa.post_id,
             acting_user_id: pa.user_id,
           )
      UserAction.log_action!(
        action_type: UserAction::ACTIONABLE_RECEIVED,
        user_id: pa.post.user_id,
        acting_user_id: pa.user_id,
        target_post_id: pa.post_id,
        target_topic_id: pa.post.topic_id,
        created_at: pa.created_at,
      )
      created_count += 1
      print "."
    else
      skipped_count += 1
    end
  end

  puts "\n\nBackfill complete!"
  puts "Created: #{created_count} UserAction records"
  puts "Skipped: #{skipped_count} (already existed)"
end
