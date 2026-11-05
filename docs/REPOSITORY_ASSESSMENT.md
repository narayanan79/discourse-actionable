# Repository assessment

Assessment of `narayanan79/discourse-actionable` at baseline commit `ce2c228`,
written from the implementation itself (not from the README) and checked
against Discourse core `2026.11.0-latest` (`b7d63fa`).

## Project purpose

A Discourse plugin that adds an **Actionable** reaction next to the like button.
A signed-in user can mark someone else's post as "requiring action". The plugin
shows a count and who marked it, keeps per-user "given / received" statistics,
adds two user-activity tabs and two user-summary lists, and adds two columns to
the user directory.

## Technology stack

| Layer | Technology |
| --- | --- |
| Host application | Discourse (Rails 8.1, Ruby 4.0, PostgreSQL, Redis, Sidekiq) |
| Server code | Ruby: one controller, two `Service::Base` services, one ActiveRecord model, two `prepend` extensions, one rake task |
| Client code | Ember (Glimmer components in `.gjs`), Discourse plugin API, MessageBus |
| Styles | SCSS registered through `register_asset` |
| Persistence | Core tables `post_actions`, `user_actions`, `user_stats`, `directory_items`, `posts`, `post_action_types`, plus the plugin table `actionable_daily` |
| Tests | RSpec (request/service/model/system) and QUnit, both run inside a Discourse checkout |

The plugin has no `Gemfile` or `package.json` of its own; everything comes from core.

## Architecture overview

```
Browser (Ember)                                   Rails (plugin code)
---------------------------------------------     -----------------------------------------------
post-menu-buttons transformer                      ActionableController
  └─ ActionableButton (.gjs)  ── POST/DELETE ──▶     ├─ ActionableActionCreator   (Service::Base)
       ├─ toggle               /actionable/:id      │    ├─ PostActionCreator (core) → post_actions
       └─ who-actioned list ── GET ───────────▶     │    ├─ UserAction.log_action! ×2 → user_actions, user_stats
                               /actionable/:id/who  │    ├─ ActionableDaily        → actionable_daily
MessageBus /topic/:id ◀── publish_change_to_clients  │    └─ posts.actionable_count recount
  (actioned / unactioned)                            ├─ ActionableActionDestroyer (mirror image)
User summary / activity connectors                   └─ who_actioned (inline query)
  └─ read serializer fields added in plugin.rb
                                                    plugin.rb: serializers, events, directory SQL,
                                                    UserSummary / UserAction extensions
```

### Major components (baseline)

| Component | File | Responsibility |
| --- | --- | --- |
| Plugin manifest | `plugin.rb` | Settings, assets, routes, serializer fields, event handlers, directory columns, `PostActionType` seed, core extensions |
| HTTP API | `controllers/actionable_controller.rb` | `POST`/`DELETE /actionable/:post_id`, `GET /actionable/:post_id/who` |
| Create service | `lib/actionable_action_creator.rb` | Checks policy and rate limit, creates the `PostAction`, logs `UserAction` rows, recounts, triggers the event |
| Destroy service | `lib/actionable_action_destroyer.rb` | Soft-deletes the action, removes `UserAction` rows, decrements stats, recounts |
| Daily tracking | `lib/actionable_daily.rb` | Per-user/per-day counter table (write-only in practice; see findings) |
| Cache helper | `lib/actionable_cache_helper.rb` | Invalidates `/u/:username/summary.json` cache entries |
| Summary extension | `lib/user_summary_extension.rb` | "Most actionabled by / given to" queries (copies of core like queries) |
| Backfill | `lib/tasks/backfill_actionable_user_actions.rake` | Recreates missing `user_actions` rows |
| Migrations | `db/migrate/*` | `actionable_daily` table, post action type 50, `posts.actionable_count`, directory and `user_stats` columns |
| Post menu button | `assets/.../components/actionable-button.gjs` | Toggle, count, who-actioned list, real-time updates |
| Initializers | `assets/.../initializers/*.js` | Registers the button, tracked post properties, and an unused icon replacement |
| Connectors / routes | `assets/.../connectors`, `routes/user-activity/*` | Summary stats, summary lists, activity tabs |

### Identifiers the plugin claims

| Identifier | Value | Where |
| --- | --- | --- |
| `post_action_types.id` | `50` | Migration 2, seed |
| `UserAction` types | `18` given, `19` received | `plugin.rb` constants, JS routes, locale keys |
| Companion plugin `discourse-insightful` | `51`, `20`/`21` | Read from that repository; no collision |

## Data flow: marking a post

1. `POST /actionable/:post_id` → `ActionableController#create` → `ActionableActionCreator`.
2. The contract validates `post_id`; the model step loads the post. The policy checks the plugin setting, trust level, own post, deleted/archived/closed topic, and an existing action. A second policy consumes a `RateLimiter` slot.
3. Core `PostActionCreator` (with `silent: true`) inserts `post_actions` (type 50) after its own guardian check (`post_can_act?`).
4. The plugin writes `actionable_daily` (+1) and `user_actions` (18 for the giver, 19 for the receiver). Through the plugin's `update_like_count` override this also writes `user_stats.actionable_given/received` (+1, except in PMs).
5. The plugin recounts `posts.actionable_count`, invalidates user-summary cache keys, and triggers `:actionable_created`.
6. A `:actionable_created` listener publishes `{type: "actioned", actionable_count, actioned_by}` on `/topic/:id`.
7. The response includes the fresh count and serializer flags. The component updates local state.

Unmarking follows the same path in reverse. Undo is only possible within core's
`post_undo_action_window_mins` (default 10 minutes), because the policy delegates to
`Guardian#can_delete_post_action?`.

## External system dependencies

| Dependency | Use |
| --- | --- |
| PostgreSQL | All persistence |
| Redis | `RateLimiter`, `Discourse.cache` (summary cache), MessageBus, (after remediation) `DistributedMutex` |
| MessageBus | Real-time count updates |
| Sidekiq / MiniScheduler | Core directory refresh (runs the plugin's directory SQL); after remediation also the plugin's cleanup job |

No third-party network services are called.

## Build and execution workflow

The plugin is cloned into `discourse/plugins/` and Discourse is rebuilt
(`./launcher rebuild app`). The rebuild runs `db:migrate`, which applies the
plugin migrations and seed fixtures, and the Ember build, which compiles
`assets/javascripts`. At boot, `plugin.rb` registers settings, assets, routes,
serializer fields and listeners.

## Testing strategy (baseline)

Seven RSpec files and two QUnit files exist, but they target an API that no
longer matches the code or core (see `BASELINE_REPORT.md` §3). There is no CI
workflow, no linter configuration, and no record of the suite ever passing.

## Deployment architecture

The plugin has no deployment artifacts of its own. It ships inside the Discourse container image built by
`discourse_docker`'s launcher. Configuration consists entirely of four site settings.

## Architectural strengths

- Builds on core primitives (`PostAction`, `UserAction`, `user_stats`,
  directory columns) instead of parallel tables, so activity streams, summary
  sections and the directory work with little custom code.
- Uses `Service::Base` with a contract, model and policies: a sound structure
  to build on.
- Denormalizes the count (`posts.actionable_count`), so rendering a post needs no
  aggregate query.
- Publishes through `Post#publish_change_to_clients!`, which applies the
  topic's secure audience: PM and secure-category updates are not leaked.

## Architectural weaknesses

1. **Bookkeeping is spread across several writes with no atomicity.** Six
   writes per toggle (`post_actions`, `user_actions` ×2, `user_stats` ×2,
   `actionable_daily`, `posts`) run without a transaction, and step failures
   are swallowed. Any partial failure leaves the counters inconsistent while
   the API reports success.
2. **Counters are maintained incrementally, with no reconciliation.** Core
   re-syncs like counts during directory refresh. The plugin's `user_stats`
   counters have no repair path, so any drift is permanent.
3. **The type registration is incomplete.** Core resolves post action types from
   the `flags` table, so type 50 is unknown to core. As a result, core's generic
   `POST /post_actions` endpoint lets users create type-50 actions while
   bypassing every plugin rule.
4. **Permission rules are duplicated.** They are hand-coded separately in the
   serializer (`can_toggle_actionable`) and the service policy, and the two copies
   disagree (closed topics).
5. **Hard-wired assumptions about core internals.** The summary cache-key format,
   copies of core's like-counting logic, and DOM order overrides already went
   stale against current core and caused user-visible bugs.
6. **The front end keeps a second copy of server state.** Its local overrides
   mask later real-time updates, and each post component holds its own
   MessageBus subscription.

## Where the architecture will fail as usage grows

- The directory refresh cost grows with the **entire** `user_actions` table
  (12 full scans per refresh), not with actionable activity.
- Each post serialized in a topic view costs about 6 extra queries for
  signed-in users, so long topics multiply this.
- `actionable_daily` grows without bound because its cleanup was disabled.
- Each like anywhere in the forum triggers dozens of no-op Redis `DEL`s,
  because summary-cache invalidation is hooked to `like_created` and
  `like_destroyed`.

## Areas requiring further investigation

- Running the RSpec, QUnit and system suites inside a Discourse checkout. This
  could not be done here (see `BASELINE_REPORT.md` §1).
- Whether production sites already have negative or drifted
  `user_stats.actionable_*` values. The new `actionable:recalculate_stats` task
  repairs them; run it after upgrading.
- Whether any site relies on the full `index_posts_on_actionable_count` index
  (for example in Data Explorer queries) before replacing it with a partial index.
- Collision risk of the hard-coded IDs (`50`, `18`, `19`) with other third-party
  plugins installed on the same site.
