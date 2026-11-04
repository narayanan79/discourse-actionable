# frozen_string_literal: true

desc "Backfill UserAction records for existing actionable PostActions"
task "actionable:backfill_user_actions" => :environment do
  puts "Starting backfill of actionable UserAction records..."

  type_id = DiscourseActionable::POST_ACTION_TYPE_ID
  post_actions = PostAction.where(post_action_type_id: type_id)
  puts "Found #{post_actions.count} actionable post actions to process"

  created_count = 0
  skipped_count = 0
  ownerless_count = 0

  post_actions.find_in_batches(batch_size: 1000) do |batch|
    # Posts may have been trashed since they were marked; keep their history.
    posts = Post.with_deleted.where(id: batch.map(&:post_id)).index_by(&:id)

    batch.each do |post_action|
      post = posts[post_action.post_id]
      if post.nil? || post.user_id.nil?
        ownerless_count += 1
        next
      end

      shared = {
        acting_user_id: post_action.user_id,
        target_post_id: post.id,
        target_topic_id: post.topic_id,
        created_at: post_action.created_at,
      }

      [
        { action_type: DiscourseActionable::USER_ACTION_GIVEN, user_id: post_action.user_id },
        { action_type: DiscourseActionable::USER_ACTION_RECEIVED, user_id: post.user_id },
      ].each do |row|
        attributes = shared.merge(row)
        if UserAction.exists?(attributes.except(:created_at))
          skipped_count += 1
        else
          UserAction.log_action!(attributes)
          created_count += 1
        end
      end
    end
  end

  puts "Backfill complete!"
  puts "Created: #{created_count} UserAction records"
  puts "Skipped: #{skipped_count} (already existed)"
  puts "Skipped: #{ownerless_count} post actions whose post or author no longer exists"
end
