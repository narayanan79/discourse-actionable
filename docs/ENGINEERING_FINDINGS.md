# Engineering findings (defect register)

Scope: `narayanan79/discourse-actionable` at baseline `ce2c228`, audited
against Discourse core `2026.11.0-latest` (`b7d63fa`).

**Confidence levels**

- **Confirmed (executed):** reproduced by running code or SQL in this environment.
- **Confirmed (source):** follows unambiguously from the plugin code combined with the cited core source.
- **Probable:** strong evidence, but depends on site data or configuration.
- **Potential:** a risk worth tracking.

**Status values**

- **Fixed:** code changed and checked statically (parse, review against core source).
- **Fixed (verified: …):** the fix itself was executed in this environment (PostgreSQL, concurrency, key coverage).
- **Fixed (verified: CI …):** the regression test for the finding ran and passed in CI on narayanan79/discourse-actionable#1 (see `TESTING.md`).
- **Fixed (runtime unverified):** code changed, but no test exercises this behaviour specifically, so a passing CI run does not confirm it.
- **Deferred:** intentionally not changed, with a reason.

## Summary

| ID | Category | Severity | Confidence | Title | Status |
| --- | --- | --- | --- | --- | --- |
| F-01 | Security / authz | Medium | Confirmed (source) | Core `POST /post_actions` accepts type 50 and bypasses every plugin rule | Fixed (verified: CI spec) |
| F-02 | Security / info leak | Medium | Confirmed (source) | Marking a post you cannot see returns 200 and its actionable count | Fixed (verified: CI spec) |
| F-03 | Privacy | Medium | Confirmed (source) | Summary lists expose real names when `enable_names` is off | Fixed (verified: CI spec) |
| F-04 | Privacy | Low | Confirmed (source) | Summary stats ignore the `can_see_summary_stats?` guardian hook | Fixed (runtime unverified) |
| F-05 | Privacy | Low | Confirmed (source) | Who-actioned list ignores the viewer's ignored users | Fixed (verified: CI spec) |
| F-06 | Data integrity | High | Confirmed (source) | Failures are swallowed: partial writes are reported as success, with no transaction | Fixed (verified: CI spec) |
| F-07 | Data integrity | High | Confirmed (source) | `user_stats` counters drift (unconditional decrement) | Fixed (verified: repair SQL; CI spec) |
| F-08 | Data integrity | Medium | Confirmed (source) | `ActionableDaily.increment_for` race: `retry` re-runs `create!` | Fixed (verified: concurrent upsert) |
| F-09 | Data integrity / ops | Medium | Confirmed (executed) | Migration 3 aborts on legacy blank values and rewrites every `posts` row twice | Fixed (verified: PostgreSQL) |
| F-10 | Reliability | Medium | Confirmed (source) | Backfill task crashes on trashed posts or deleted authors | Fixed (verified: CI spec) |
| F-11 | Data integrity | Low | Confirmed (executed) | Duplicate unique index on `actionable_daily` | Fixed (verified: PostgreSQL) |
| F-12 | Data integrity | Low | Confirmed (source) | Daily counter is decremented on the wrong day | Fixed (verified: CI spec) |
| F-13 | Functional | High | Confirmed (source) | Summary cache invalidation is a no-op (wrong key format) | Fixed (verified: CI spec) |
| F-14 | Functional | Medium | Confirmed (source) | Directory columns: disabling the plugin never hides them; refresh overrides the admin's choice | Fixed (verified: CI spec) |
| F-15 | Functional | Medium | Confirmed (source) | Closed topics: button is enabled but the server always refuses | Fixed (verified: CI spec) |
| F-16 | Functional (UI) | Medium | Confirmed (source) | Stale UI: local overrides mask real-time updates after the first toggle | Fixed (verified: CI QUnit) |
| F-17 | Functional | Low | Confirmed (source) | Who-actioned `total_count` is capped at 50 and has no ordering | Fixed (verified: CI spec) |
| F-18 | Functional | Low | Confirmed (source) | `can_undo_actionable` ignores the undo window | Fixed (verified: CI spec) |
| F-19 | Maintainability | Low | Confirmed (source) | `PostActionType.types[:actionable] = 50` is a no-op | Fixed |
| F-20 | UX | Low | Confirmed (source) | Anonymous click gives a 403 error dialog instead of the login prompt | Fixed (verified: CI QUnit and system spec) |
| F-21 | UX / performance | Low | Confirmed (source) | `console.warn` on every publish, plus one MessageBus subscription per post | Fixed (runtime unverified) |
| F-22 | Performance | Medium | Confirmed (source) | About 6 extra queries per serialized post (N+1) | Fixed (verified: CI spec) |
| F-23 | Performance | Medium | Confirmed (executed) | Directory SQL fully scans `user_actions` 12 times per refresh | Fixed (verified: EXPLAIN ANALYZE) |
| F-24 | i18n | Low | Confirmed (source) | API error messages are hard-coded English | Fixed (verified: key coverage) |
| F-25 | Performance | Low | Confirmed (source) | Summary list queries run twice per request | Fixed (runtime unverified) |
| F-26 | Performance | Low | Confirmed (source) | Every toggle also broadcasts topic stats | Fixed (runtime unverified) |
| F-27 | Reliability | Low | Confirmed (source) | `PostActionType.seed` runs on every process boot | Fixed (runtime unverified) |
| F-28 | Operations | Medium | Confirmed (source) | `actionable_daily` grows without bound (cleanup disabled) | Fixed (verified: CI spec) |
| F-29 | UI | Medium | Confirmed (source) | Global CSS overrides restyle every user page | Fixed (not visually verified) |
| F-30 | Quality | High | Confirmed (source) | Test suite cannot pass; no CI or linter configuration | Fixed (verified: CI passes) |
| F-31 | Maintainability | Low | Confirmed (source) | `update_like_count` override duplicates core like logic | Fixed |
| F-32 | Maintainability | Low | Confirmed (source) | Dead code (icon initializer, `to_prepare`, unused properties/keyframes, duplicate helpers) | Fixed |
| F-33 | Maintainability | Low | Confirmed (source) | Internal/deprecated front-end APIs and import paths | Fixed (verified: CI lint) |
| F-34 | Reliability | Low | Confirmed (source) | Migration 2 depends on application model code | Fixed |
| F-35 | Documentation | Low | Confirmed (source) | README is inaccurate (clone URL, icons, claims, missing LICENSE) | Fixed (LICENSE left to owner) |
| F-36 | Functional | Low | Confirmed (executed) | Directory counts include PMs and deleted/hidden posts, unlike profile stats | Fixed (verified: PostgreSQL) |
| F-37 | Performance | Low | Potential | Full `index_posts_on_actionable_count` index on the hot `posts` table is unused by the plugin | Deferred |
| F-38 | Maintainability | Low | Potential | Hard-coded IDs (50/18/19) may collide with other third-party plugins | Deferred |
| F-39 | Data integrity / ops | High | Confirmed (executed) | FK `actionable_daily.user_id → users` makes deleting users who marked posts fail | Fixed (verified: PostgreSQL) |
| F-40 | Data integrity | Low | Confirmed (source) | Deleting a user leaves other users' `actionable_received` and `posts.actionable_count` stale | Deferred (repair task) |
| F-41 | Functional | Medium | Confirmed (source) | `before_directory_refresh` handler registered as a Symbol never runs (core triggers a String) | Fixed (handler removed) |
| F-42 | Privacy | Medium | Confirmed (source) | Core `/post_action_users` lists who marked a post to anyone, ignoring `actionable_show_who_actioned` | Fixed (verified: CI spec) |
| F-43 | Privacy | Low | Confirmed (source) | MessageBus payload exposes `actioned_by` to all topic viewers | Fixed (verified: CI spec) |
| F-44 | UI | Low | Confirmed (source) | Who-actioned popup cannot be closed from its own count button (wrong post's button targeted) | Fixed (runtime unverified) |
| F-45 | Data integrity | Medium | Confirmed (executed) | Concurrent mark + unmark of one post store a wrong `actionable_count` | Fixed (verified: two-session PostgreSQL race) |

## Details

Each entry gives its location, root cause, impact, how to reproduce it, the
planned remediation, and how the fix is verified.

### F-01: core `/post_actions` endpoint accepts actionable (type 50)

- **Location:** core `PostActionsController#create`/`#destroy` combined with plugin type 50.
- **Root cause:** `fetch_post_action_type_id_from_params` accepts any integer. For
  50, `PostActionCreator` resolves `@post_action_name = PostActionTypeView#types[50] = nil`
  (types come from the `flags` table). `Guardian#post_can_act?(post, nil)` then
  returns true for any visible, non-archived, non-deleted post. The own-post
  check applies only to `:like`.
- **Impact:** any signed-in user can create or remove actionable marks through
  `POST /post_actions {id, post_action_type_id: 50}`. This also works on their
  own posts, below the minimum trust level, on closed topics, past the daily
  limit, and while the plugin is **disabled**. None of the bookkeeping runs
  (`user_actions`, `user_stats`, `posts.actionable_count`, `actionable_daily`), so
  counts diverge from reality.
- **Reproduction:** `post "/post_actions.json", params: { id: own_post.id, post_action_type_id: 50 }` returns 200 and creates a `PostAction`.
- **Remediation:** prepend a `PostActionsController` extension that rejects type 50
  with 403 (`Discourse::InvalidAccess`), so the plugin endpoint is the only way in.
- **Verification:** `spec/requests/post_actions_controller_spec.rb`.

### F-02: hidden posts leak their count; success is reported for refused actions

- **Location:** `ActionableActionCreator#can_create_actionable`, `#create_action`; `ActionableController#create`.
- **Root cause:** the policy never checks visibility. When core's
  `PostActionCreator` refuses (it does check `can_see_post?`), `create_action`
  returns `false`. A generic `Service::Base` step's return value is ignored
  (`lib/service/base/step.rb`; documented in core's service guide), so the
  service succeeds. The controller then serializes the hidden post and returns its
  `actionable_count`.
- **Impact:** confirms that a post exists and reveals its actionable count for posts
  in private categories or PMs. The response claims `success: true` for an
  action that was never taken.
- **Remediation:** add a visibility check to the policy (`Guardian#can_mark_post_actionable?`),
  call `fail!` when core refuses, and remove the blanket `rescue`.
- **Verification:** service spec (PM post fails the policy) and request spec (403 with no count in the body).

### F-03: real names exposed in summary lists

- **Location:** `plugin.rb` serializers `most_actionabled_by_users` / `most_actionabled_users`.
- **Root cause:** the hashes are built by hand, so they skip core's
  `UserSummarySerializer::UserWithCountSerializer#include_name?` (`SiteSetting.enable_names?`).
- **Impact:** users' full names appear in `/u/:username/summary.json` on sites
  that disabled names. The hashes also omit flair, admin, moderator and trust-level fields.
- **Remediation:** serialize through `UserSummarySerializer::UserWithCountSerializer`.
- **Verification:** request spec with `enable_names = false`.

### F-04: summary stats bypass `can_see_summary_stats?`

- **Root cause:** `actionable_given` / `actionable_received` have no include condition.
  Core gates `likes_given` / `likes_received` on `scope.can_see_summary_stats?`.
- **Remediation:** add `include_condition: -> { scope.can_see_summary_stats?(object.user) }`.

### F-05: who-actioned ignores ignored users

- **Root cause:** the inline query in `who_actioned` lacks the `ignored_users` filter
  that core's `PostActionUsersController` applies.
- **Remediation:** apply the same `NOT EXISTS ignored_users` filter.

### F-06: swallowed failures and partial writes

- **Location:** both services.
- **Root cause:** about six writes run without a transaction. `rescue => e`
  converts every error to `false`, and generic step results are ignored by
  `Service::Base`.
- **Impact:** an exception after `PostActionCreator` (for example `post.user` is nil
  because the author was deleted, so `post.user.id` raises) leaves a `post_action`
  without its `user_actions`, stats or count. The client still receives `success: true`.
- **Remediation:** wrap the writes in `transaction`, guard them with `lock(:post_id)`, use
  `fail!` for refusals, let unexpected errors propagate, and keep side effects outside the transaction.
- **Verification:** service specs for the deleted-author and refusal paths.

### F-07: `user_stats` drift

- **Root cause:** `UserAction.log_action!` increments only when the topic is not a
  PM and the row is new. The destroyer always calls `update_like_count(-1)`
  twice: in PMs, for actions that predate user-action logging, and on concurrent
  double `DELETE`.
- **Impact:** permanently wrong or negative "Actionable Given/Received" stats.
- **Remediation:** decrement only for rows actually deleted (count returned by
  `delete_all`) and only for non-PM topics. Add an `actionable:recalculate_stats`
  task to repair existing drift.
- **Verification:** service spec (PM topic leaves stats unchanged); rake task spec.

### F-08: daily counter race

- **Root cause:** `rescue ActiveRecord::RecordNotUnique; retry` re-runs `create!`, not
  the `UPDATE`. The uniqueness validation then raises `RecordInvalid`.
- **Remediation:** a single atomic `INSERT … ON CONFLICT … DO UPDATE`.

### F-09: migration 3 (`add_actionable_count_to_posts`)

- **Evidence (executed, PostgreSQL 16):** a blank legacy custom field aborts the
  migration with `invalid input syntax for type integer: ""`. On clean data, each of
  its two `UPDATE`s rewrote 100,000 of 100,000 posts, although 9,495 had actionables.
- **Remediation:** remove the redundant custom-field step (it is overwritten by the
  next statement) and recount only posts that have actionable actions. The end
  state is identical. Sites that already ran the migration are unaffected.
- **Verification:** both versions run on the scratch database and the resulting
  `posts.actionable_count` values are compared.

### F-10: backfill task crash

- **Root cause:** `pa.post` is `nil` for trashed posts (`Post` default scope), and
  `pa.post.user_id` is `nil` for deleted authors (`log_action!` requires it).
- **Remediation:** load with `Post.with_deleted` and skip ownerless posts with a counter.

### F-11: duplicate unique index

- **Evidence (executed):** migrations 1 and 7 both create a unique index on
  `actionable_daily (user_id, actionable_date)`.
- **Remediation:** new migration drops `index_actionable_daily_on_user_and_date` if it exists.

### F-12: daily decrement uses today's date

- **Remediation:** decrement the row for the date the action was created.

### F-13: summary cache invalidation is a no-op

- **Root cause:** core's key is
  `user_summary:<user>:<viewer>:<locale>:<auto_translate>` (`UsersController#summary_cache_key`).
  The plugin deletes 3- and 4-segment keys that never exist, issuing
  2 × 2 × (locales + 1) Redis round-trips per action and per like.
- **Impact:** stats remain stale for up to an hour. This is the root cause behind
  the repeated "fix stats not updating" commits.
- **Remediation:** build the 5-segment key for both auto-translate values and delete all variants in one batched call.
- **Verification:** request spec that loads the summary (filling the cache), marks a post, and reloads the summary.

### F-14: directory column sync

- **Root cause:** `on(:site_setting_changed)` is skipped once the plugin is disabled,
  because `Plugin::Instance#on` checks `enabled?`. So turning the plugin **off** never
  hides the columns. The `to_prepare` block registered after boot is dead code, and the
  `before_directory_refresh` handler never runs (F-41).
- **Remediation:** `on_enabled_change` shows the columns when the plugin is turned on and
  hides them when it is turned off. The dead handlers are removed. Columns keep core's
  default (created hidden; the admin chooses), which is what sites actually experienced
  before because the refresh handler never ran.

### F-15: closed topics

- **Root cause:** the service refuses `topic.closed?`, but the
  `can_toggle_actionable` serializer does not check it.
- **Remediation:** one `Guardian#can_mark_post_actionable?` predicate used by
  both the policy and the serializer. The enforced behavior (closed topics refused) is preserved.

### F-16: stale UI after the first toggle

- **Root cause:** `localActioned`, `localActionableCount` and
  `localCanToggleActionable` are set on toggle and never reset. The getters prefer
  them over the tracked post properties that MessageBus updates.
- **Remediation:** the tracked post model is the single source of truth.

### F-17: who-actioned total capped at 50

- **Root cause:** `actions.count` is evaluated on a `.limit(50)` relation, which
  Rails turns into `COUNT` over a `LIMIT 50` subquery. There is also no `ORDER BY`.
- **Remediation:** count without the limit, order by `created_at`, and keep the 50-user cap.

### F-18: `can_undo_actionable` ignores the undo window

- **Remediation:** return `actioned && guardian.can_delete_post_action?(action)`.

### F-19: no-op `PostActionType.types` patch

- **Root cause:** `PostActionType.types` returns a new `Enum` on every call, so assigning into it has no effect.
- **Remediation:** remove the patch and use the constant `DiscourseActionable::POST_ACTION_TYPE_ID`.

### F-20: anonymous click

- **Remediation:** for anonymous users the button calls `buttonActions.showLogin()`,
  as core's like button does.

### F-21: MessageBus handling

- **Root cause:** core's topic controller warns on unknown message types unless a
  `registerCustomPostMessageCallback` handler exists. Each post component also
  subscribes separately.
- **Remediation:** register one callback per message type; it updates the tracked
  post model. Remove the per-component subscriptions.

### F-22: N+1 queries in the post serializer

- **Root cause:** `actioned`, `can_undo_actionable` and `can_toggle_actionable`
  each run `PostActionType.find_by` plus a `PostAction` query, about 6 queries per post.
- **Remediation:** use the topic view's preloaded `all_post_actions`, the constant type ID,
  and memoization. Fall back to one query only outside a topic view.
- **Verification:** serializer spec using `track_sql_queries`.

### F-23: directory SQL performance

- **Evidence (executed):** `Seq Scan on user_actions` reads 1,020,000 rows per column
  per period (380–454 ms each on 1M rows), 12 scans per refresh.
- **Remediation:** aggregate only `action_type = 18/19` rows, which can use
  `index_user_actions_on_action_type_and_created_at`, then update through a join.
- **Verification:** `EXPLAIN ANALYZE` before and after on the same data.

### F-24: hard-coded English errors

- **Remediation:** server locale keys and `I18n.t`.

### F-25: summary list queries run twice

- **Remediation:** memoize in `UserSummaryExtension`.

### F-26: topic stats broadcast on every toggle

- **Remediation:** pass `skip_topic_stats: true` (actionable marks do not change topic stats).

### F-27: seed on every boot

- **Remediation:** move it to `db/fixtures/` and register it with `register_seedfu_fixtures`. It then runs during `db:migrate`.

### F-28: unbounded `actionable_daily`

- **Remediation:** `Jobs::CleanupActionableDaily`, daily, keeping 90 days (the retention in the original commented-out code).

### F-29: global CSS

- **Root cause:** `.user-main .user-content { display: flex }` matches the
  activity, messages, preferences, badges and notifications pages (core templates
  `user-activity.gjs`, `user/messages.gjs`, `preferences.gjs`, `user/badges.gjs`,
  `user-notifications.gjs`). Floated children stop floating inside a flex container.
- **Remediation:** scope the ordering rules to `.user-summary-page`.

### F-30: tests and quality gates

- **Remediation:** rewrite the RSpec and QUnit suites to current conventions. Add
  Discourse's standard plugin CI workflow and linter configs (copied from
  `discourse-plugin-skeleton` so the lockfiles match).

### F-31: `update_like_count` override

- **Remediation:** handle only plugin types and call `super` for everything else. Namespace the module.

### F-32: dead code

- **Remediation:** delete it (listed in `REMEDIATION_LOG.md`).

### F-33: internal or deprecated front-end APIs

- `_addTrackedPostProperty`, versioned `withPluginApi`, pre-ui-kit import paths
  (flagged as errors by `@discourse/lint-configs`), `truth-helpers`.
- **Remediation:** public `api.addTrackedPostProperties`, ui-kit paths,
  `discourse/truth-helpers`. Add a `.discourse-compatibility` pin so older cores keep the baseline commit.

### F-34: migration depends on application code

- **Remediation:** rewrite migration 2 as an idempotent `INSERT … WHERE NOT EXISTS`. Already-migrated sites are unaffected.

### F-35: documentation

- README clones from `github.com/discourse/discourse-actionable` (wrong owner).
  It describes check-square icons and claims `ActionableDaily` enforces quotas, zero
  RuboCop offenses and comprehensive coverage. It references a `LICENSE` file that
  does not exist.
- **Remediation:** rewrite the README. Adding a LICENSE is left to the owner (a legal decision).

### F-36: directory semantics

- **Root cause:** the directory SQL counts every 18/19 row. Profile stats exclude PMs,
  and core's like columns count only visible posts in regular topics
  (`UserStat::COUNTABLE_POST_CONDITIONS`).
- **Remediation:** apply the same countable-post conditions in the directory SQL. This is a documented behavior change.

### F-37: full index on `posts.actionable_count`

- Unused by plugin queries, but it may support ad-hoc reports. Swapping it for a
  partial index (`WHERE actionable_count > 0`) is an operational decision on the hot
  `posts` table; recommended, not applied.

### F-38: hard-coded identifiers

- Changing 50/18/19 would require migrating existing data. Documented as a limitation.

### F-39: foreign key blocks user deletion

- **Location:** `db/migrate/20250101000001_create_actionable_daily_table.rb`
  (`t.references :user, foreign_key: true`).
- **Root cause:** a `NO ACTION` foreign key from `actionable_daily.user_id` to
  `users.id`. Core's `UserDestroyer` and `User#before_destroy` clean up core tables
  only (`GivenDailyLike`, `PostAction`, `UserAction`, …), not plugin tables.
- **Evidence (executed):** with an `actionable_daily` row present,
  `DELETE FROM users` fails with `violates foreign key constraint
  "actionable_daily_user_id_fkey"`. Because cleanup had been disabled (F-28), this
  affects every user who ever marked a post: admin deletion, "delete spammer" and
  GDPR erasure all fail.
- **Remediation:** the post-deploy migration removes the FK (SafeMigrate forbids
  `DROP CONSTRAINT` pre-deploy). Migration 1 no longer creates it on fresh installs,
  and an `on(:user_destroyed)` handler deletes the user's rows.
- **Verification:** after dropping the constraint, the same `DELETE` succeeds
  (PostgreSQL). Covered by `spec/integration/user_destroyer_spec.rb`.

### F-40: counters after user deletion

- **Root cause:** core's `User#before_destroy` hard-deletes the user's `post_actions`
  and every `user_actions` row they appear in, without plugin hooks, so other users'
  `actionable_received` and the affected posts' `actionable_count` are not updated.
- **Status:** Deferred. Repair with `rake actionable:recalculate_stats`. Core has the
  same behaviour for likes until its directory refresh re-syncs them.

### F-41: `before_directory_refresh` handler never ran

- **Root cause:** `DiscourseEvent.events` is keyed by the exact object passed in.
  Core triggers `"before_directory_refresh"` (a String,
  `app/models/directory_item.rb:41`); the plugin registered
  `on(:before_directory_refresh)` (a Symbol).
- **Impact:** the intended column sync never happened, so columns stayed in core's
  default hidden state unless an admin toggled the plugin.
- **Remediation:** handler removed; see F-14 for the replacement behaviour.

### F-42 to F-45: found by the independent review

These are baseline defects that a second, independent code review found after
the first remediation pass.

- **F-42:** `PostActionUsersController#index` (core) needs no login and lists actors
  when `Guardian#can_see_post_actors?` is true. For a type it does not know (50), that
  is always true. Fixed by `PostActionUsersControllerExtension`, which rejects type 50 (403).
- **F-43:** `publish_change_to_clients!` sends the payload to everyone who can see the
  topic. `actioned_by` is now included only when `actionable_show_who_actioned` is on
  (the client then updates the count only).
- **F-44:** `DCloseOnClickOutside` resolves `targetSelector` with
  `document.querySelector`, which returns the first `.actionable-count` on the page. For
  any other post, pressing its own count closes the list on pointerdown and reopens
  it on click. Fixed with a per-post id (`actionable-count-<post id>`) used as the selector.
- **F-45:** each transaction counted rows that the other had not yet committed, so the
  last writer stored a stale value. The service `lock` step cannot help, because its
  key includes the service class. `Post#update_actionable_count` now takes the post row lock
  before counting. **Evidence:** without the lock, two overlapping PostgreSQL sessions stored
  2 for 1 real mark (2 of 2 runs); with it, 1 (3 of 3 runs).
