# Remediation log

Changes made on 2026-11-04 on top of baseline `ce2c228`. Finding IDs refer to
`ENGINEERING_FINDINGS.md`. "Verified" means checked by execution in this
environment. The RSpec and QUnit suites could not be run here (see
`BASELINE_REPORT.md` §1); they later ran in CI (see "CI fixes" below).

## Server

| File | Change | Why | Verification |
| --- | --- | --- | --- |
| `plugin.rb` | Namespaced constants; one `reloadable_patch` for all prepends; serializer fields read preloaded post actions; summary lists use core's `UserWithCountSerializer` with include conditions; `on_enabled_change` for directory columns; `:user_destroyed` cleanup; seed fixtures registered; numeric route constraint. Removed: the no-op `PostActionType.types[]=` patch, the boot-time `PostActionType.seed`, the dead `before_directory_refresh` handler (registered under a Symbol while core triggers a String), the ineffective `to_prepare` block, the inline `update_like_count` module, and unused icons. `required_version` set to 2026.5.0, version 1.1.0. | F-03, F-04, F-14, F-19, F-22, F-25, F-27, F-31, F-32, F-39 | Ruby parse; core API signatures checked in source |
| `lib/guardian_extension.rb` (new) | `can_mark_post_actionable?`: enabled, signed in (not anonymous mode), post visible, not own, author present, topic open/unarchived, trust level | F-02, F-15 | spec |
| `lib/actionable_action_creator.rb` | Visibility policy; `lock(:post_id)` + `transaction`; `fail!` when core refuses; no blanket `rescue`; events/MessageBus/cache after commit; `skip_topic_stats` | F-02, F-06, F-26 | spec |
| `lib/actionable_action_destroyer.rb` | Same structure; decrements only the user actions actually deleted and never in PMs; daily decrement on the action's own date | F-06, F-07, F-12 | spec |
| `controllers/actionable_controller.rb` | `requires_plugin`; daily limit checked before and consumed only on success (429 with wait time); translated errors; 503 when the lock is unavailable; who-actioned ordered, true total, ignored users hidden | F-17, F-24, F-05 | spec |
| `lib/post_actions_controller_extension.rb` (new) | Core `/post_actions` refuses type 50 | F-01 | spec |
| `lib/post_serializer_extension.rb` (new) | Memoized lookup that reuses `TopicView#all_post_actions` | F-22 | spec with positive control |
| `lib/user_action_extension.rb` (new) | `update_like_count` handles only types 18/19 (floored at 0), `super` otherwise | F-31, F-07 | Ruby parse |
| `lib/user_summary_extension.rb` | Memoized lists; queries unchanged | F-25 | spec |
| `lib/actionable_cache_helper.rb` | Core's 5-part summary key; one batched Redis `DEL`; falls back to per-key delete when the cache is not Redis-backed | F-13 | `Cache#delete` semantics checked in core; spec |
| `lib/actionable_daily.rb` | Atomic upsert; decrement by date; 90-day retention constant; removed the misleading `within_daily_limit?` | F-08, F-12, F-28 | **Verified:** 40 and 25 concurrent upserts produced 1 row with the exact count |
| `lib/directory_columns.rb` (new) | Type-filtered `MATERIALIZED` CTE with countable-post rules; unchanged rows skipped; column allow-list | F-23, F-36 | **Verified:** 0 mismatches against the reference on all rows × 6 periods; 50 ms vs 400 ms (all), 10 ms vs 400 ms (weekly) |
| `app/jobs/scheduled/cleanup_actionable_daily.rb` (new) | Daily cleanup (replaces the commented-out `every`) | F-28 | spec |
| `lib/tasks/backfill_actionable_user_actions.rake` | Batches; includes trashed posts; skips ownerless posts | F-10 | spec |
| `lib/tasks/recalculate_actionable_stats.rake` (new) | Rebuilds `user_stats.actionable_*` and `posts.actionable_count` from source rows | F-07 | **Verified:** repairs injected drift with 0 mismatches |
| `db/migrate/…0001` | Same table and indexes without `t.references`/FK (fresh installs) | F-39, lint | Ruby parse |
| `db/migrate/…0002` | Idempotent SQL insert instead of a model call | F-34 | Ruby parse |
| `db/migrate/…0003` | Data step recounts only affected posts; the failing custom-field step removed | F-09 | **Verified:** writes 9,495 rows instead of 200,000, same result |
| `db/migrate/20261104040847_…` (new) | Drops the duplicate unique index (idempotent; `down` recreates it) | F-11 | **Verified:** up ×2 and down |
| `db/post_migrate/20261104041101_…` (new) | Removes the `actionable_daily → users` FK on existing sites | F-39 | **Verified:** user delete fails with the FK and succeeds without it |
| `db/fixtures/001_actionable_post_action_type.rb` (new) | Seed moved out of boot | F-27 | Ruby parse |
| `config/settings.yml` | Bounds: `min: 0` (per day), `0..4` (trust level) | robustness | YAML parse |
| `config/locales/server.en.yml` | Error messages | F-24 | key coverage check |

## Client

| File | Change | Why | Verification |
| --- | --- | --- | --- |
| `components/actionable-button.gjs` | Tracked post properties are the only state; anonymous → `showLogin`; no per-component MessageBus; ui-kit imports; count button as a template-only component with aria-label; error message without the generic prefix | F-16, F-20, F-21, F-33 | JS syntax and template balance; QUnit written |
| `initializers/discourse-actionable.js` (new) | Replaces 3 initializers: `api.addTrackedPostProperties`, `post-menu-buttons` transformer, `registerCustomPostMessageCallback` for `actioned`/`unactioned`; runs only when enabled | F-21, F-32, F-33 | JS syntax |
| `initializers/actionable-icons.js`, `actionable-post-menu.js`, `extend-post-model.js` | Deleted (dead icon replacement; merged into the new initializer) | F-32 | — |
| `connectors/*` | ui-kit imports (`DUserStat`, `DNavigationItem`, `dIcon`), sorted imports and arguments | F-33 | JS syntax and template balance |
| `routes/user-activity/*` | `htmlSafe` → `trustHTML` (lint error in current configs) | F-33 | JS syntax |
| `stylesheets/actionable.scss` | Flex/order overrides scoped to `.user-summary-page`; dead rules removed; Stylelint-compatible | F-29 | brace balance |
| `config/locales/client.en.yml` | Pluralized count tooltips; `_long` directory column headers | i18n | key coverage check |

## Tests and tooling

| File | Change |
| --- | --- |
| `spec/**` | Rewritten to current conventions: request specs replace the broken controller spec; duplicate `spec/lib` specs removed; new serializer, integration, job, task and system specs (see `TESTING.md`) |
| `test/javascripts/**` | Rewritten: component integration tests (`.gjs`) and acceptance tests. The broken unit/acceptance files were removed. |
| `.github/workflows/discourse-plugin.yml` | Discourse's reusable plugin CI |
| `Gemfile`, `Gemfile.lock`, `package.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml`, `.npmrc`, `.rubocop.yml`, `.streerc`, `eslint.config.mjs`, `.prettierrc.cjs`, `stylelint.config.mjs` | Copied from `discourse-plugin-skeleton`. Only the `lint:types` script was removed because there is no `tsconfig.json`; dependencies are identical, so the lockfile is valid. |
| `.discourse-compatibility` | `< 2026.5.0` → `ce2c228` (checked against core's parser logic) |
| `.gitignore` | Skeleton entries added |

## Independent review fixes

A second reviewer (a separate agent given only the code and core's source)
checked the first pass. Its findings were verified against core before
changing anything.

| Problem | Introduced by | Fix | Verification |
| --- | --- | --- | --- |
| Mark and unmark not serialized for the recount (F-45) | baseline; the first pass claimed it was solved | post row lock in `Post#update_actionable_count` | **Verified:** two-session race on PostgreSQL |
| `actionable_max_per_day = 0` became unlimited | first pass (check-then-record limiter) | 0 now explicitly refuses non-staff (403) | request spec |
| Rake task spec would not find the tasks (no engine, so `load_tasks` skips the plugin's `lib/tasks`) | first pass | spec loads the plugin's rake files | — |
| Specs that could not fail (stats floored at 0; rollback asserted on writes that never ran) | first pass | non-zero starting stats; a new "last write fails" rollback test | — |
| Core `/post_action_users` exposes markers (F-42) | baseline | `PostActionUsersControllerExtension` | request spec |
| `actioned_by` broadcast to every viewer (F-43) | baseline | sent only when who-actioned is shown | service spec |
| Count button cannot close its own popup (F-44) | baseline | per-post id selector | JS syntax and template checks |
| Daily row keyed by request time but decremented by action date | first pass | increment by `post_action.created_at` too | — |
| A shorthand `params:` at end of line (paren-less call) in a spec | first pass | explicit value; a Prism scan finds no other case | **Verified:** Prism scan with negative controls |

## CI fixes (2026-11-05)

The first CI run on narayanan79/discourse-actionable#1 executed the suites
for the first time. Fixes:

| File | Problem | Fix |
| --- | --- | --- |
| `pnpm-lock.yaml` | `pnpm install --frozen-lockfile` failed: no package manager entry for `pnpm@12.11.2`. This also skipped RuboCop and Syntax Tree. | Added the entry, as generated by pnpm 12.11.2 (identical to core's) |
| `test/javascripts/acceptance/actionable-test.js` | Prettier formatting | `prettier --write` |
| `spec/requests/users_controller_spec.rb` | Anonymous summary request got a 404 from core's `hide_new_user_profiles` | The example turns the setting off |
| `spec/tasks/actionable_tasks_spec.rb` | RuboCop `Discourse/Plugins/UseRequireRelative` | `Rake.load_rakefile` instead of `load` |

The code under test did not change. Results are in `TESTING.md`.

## Documentation

README rewritten; added `docs/`: `REPOSITORY_ASSESSMENT`, `BASELINE_REPORT`,
`ENGINEERING_FINDINGS`, `ARCHITECTURE`, `DEVELOPMENT`, `TESTING`, `SECURITY`,
`DEPLOYMENT`, `REMEDIATION_LOG`, `PRODUCTION_READINESS`.

## Not changed (deliberately)

- Identifiers 50/18/19, table and column names: persisted data.
- Migrations 4, 6 and 7: already applied everywhere; superseded where needed by
  new migrations.
- `index_posts_on_actionable_count` (F-37): replacing it is an operational
  decision on the hot `posts` table.
- No `LICENSE` file added: choosing a license is the owner's decision.
