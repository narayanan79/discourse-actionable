# frozen_string_literal: true

# Sites created before this release have a foreign key from
# actionable_daily.user_id to users.id (added by `t.references`). It makes
# UserDestroyer fail with PG::ForeignKeyViolation for every user who ever
# marked a post as actionable. Discourse does not use foreign keys for this
# kind of data; the plugin deletes the rows on `:user_destroyed` instead.
class DropActionableDailyUserForeignKey < ActiveRecord::Migration[7.1]
  def up
    remove_foreign_key :actionable_daily, :users, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
