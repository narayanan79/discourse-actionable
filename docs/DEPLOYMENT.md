# Deployment

The plugin ships inside the Discourse container (`discourse_docker`). There is
nothing separate to deploy.

## Install or upgrade

1. Check the Discourse version: **2026.5.0 or newer** is required for the
   current code. Older sites automatically get the pinned commit from
   `.discourse-compatibility`.
2. Add or keep the plugin in `containers/app.yml` (see README) and run
   `./launcher rebuild app`. The rebuild runs:
   - **pre-deploy migrations** (`db/migrate`): schema and data. The rewritten
     migration 3 now touches only posts that have actionable marks.
   - **seed fixtures** (`db/fixtures`): keep post action type 50 present.
   - **post-deploy migrations** (`db/post_migrate`): drop the
     `actionable_daily → users` foreign key on existing sites. If you deploy with
     `SKIP_POST_DEPLOYMENT_MIGRATIONS=1`, run them afterwards with
     `rake db:migrate`. Until they run, deleting users who have marked posts keeps
     failing, as it did before the upgrade.
3. After upgrading from any earlier version, repair counters once:

   ```bash
   ./launcher enter app
   rake actionable:recalculate_stats
   ```

   Earlier versions could over- or under-count `user_stats.actionable_*`
   (findings F-06/F-07). The task is idempotent and only rewrites rows that
   differ.
4. If users marked posts before user actions were logged (very old versions),
   also run `rake actionable:backfill_user_actions`, then repeat step 3.

## Behaviour changes in 1.1.0

These matter to operators:

| Change | Before | After |
| --- | --- | --- |
| Marks through core's `/post_actions` | accepted, bypassing every rule | refused (403) |
| "Who marked" through core's `/post_action_users` | listed to anyone who could see the post | refused (403); use `/actionable/:id/who` |
| Real-time payload with `actionable_show_who_actioned` off | included the marking user's id | count only |
| `actionable_max_per_day = 0` | blocked non-staff (by accident of `RateLimiter`) | blocks non-staff explicitly (403) |
| Directory columns when the plugin is turned off | stayed visible | hidden; shown again when it is turned back on |
| Directory counts | counted every mark, including PMs and deleted posts | counts only public, visible posts (same rule as likes) |
| Daily limit | consumed by every attempt that passed the permission check | consumed only by successful marks |
| `actionable_daily` | grew forever | rows older than 90 days removed daily |
| Error messages | hard-coded English | translatable (`config/locales/server.en.yml`) |
| Summary stats after a mark | stale for up to one hour (invalidation was a no-op) | fresh for the owner and anonymous viewers |

## Rollback

- Code: pin the plugin to the previous commit (`ce2c228`) and rebuild.
- Schema: the 1.1.0 migrations only remove a duplicate index and a foreign key,
  and the previous code works without either. The index migration has a `down`
  method. The foreign-key removal is irreversible on purpose, because the key
  broke user deletion.
- Data: nothing is destroyed except `actionable_daily` rows older than 90 days
  (reporting data).

## Operations

| What | Where |
| --- | --- |
| Scheduled job | `Jobs::CleanupActionableDaily` (daily) in Sidekiq → Scheduler |
| Directory refresh | core's `DirectoryRefreshDaily` / `DirectoryRefreshOlder` run the plugin SQL |
| Logs | standard Rails/Sidekiq logs. Service failures surface as 4xx responses, not swallowed log lines. |
| Read-only mode | marking answers 503 (the lock needs Redis writes) |
