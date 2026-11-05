# Production readiness

## Assessment: READY WITH CONDITIONS

Every confirmed Critical, High and Medium finding in the register is fixed,
and the full CI suite passes against current Discourse core. The conditions
are the checks CI cannot make: a staging smoke test and the upgrade steps.

| Evidence | Status |
| --- | --- |
| RSpec (services, requests, serializer, integration, jobs, tasks) | **Pass in CI:** 81 examples, 0 failures |
| System specs (browser) | **Pass in CI:** 23 examples, 0 failures |
| QUnit (component, acceptance) | **Pass in CI:** 19 of 19 |
| RuboCop, Syntax Tree, ESLint, Prettier, Stylelint | **Pass in CI** |
| Database create and migrate, Zeitwerk eager load and reload, `SKIP_DB_AND_REDIS` boot | **Pass in CI** |
| `.discourse-compatibility` validation | Not run (the workflow skipped it); checked by hand against core's parser |
| All plugin SQL on PostgreSQL 16 (1M-row dataset) | Executed, correct; performance measured |
| Mark/unmark recount race (two concurrent sessions) | Executed: wrong without the row lock, correct with it |
| Independent code review against core source | Done; 5 definite and 5 possible issues reported, all verified and addressed or documented |
| Load test | Not done (see "Scaling characteristics") |

CI ran on draft PR narayanan79/discourse-actionable#1 (head `fdd965d`)
against Discourse core `latest` at `61fbb13`. Details are in `TESTING.md`.

## Conditions

1. Smoke-test on a staging site running Discourse ≥ 2026.5.0: mark and unmark,
   watch another browser update live, delete a user who has marked posts, toggle
   the plugin, refresh the directory.
2. Upgrade production, let post-deploy migrations run, then run
   `rake actionable:recalculate_stats`.

## Remaining risks

| Risk | Severity | Mitigation |
| --- | --- | --- |
| Behaviour on real site data and traffic (CI uses fabricated data) | Medium | Staging smoke test; watch the metrics under "Monitoring" after release |
| Hard-coded IDs 50/18/19 may collide with another third-party plugin | Low | Audit installed plugins; changing the IDs needs a data migration |
| `user_stats.actionable_*` drift after user deletion | Low | Periodic or post-incident `rake actionable:recalculate_stats` |
| Per-viewer summary cache staleness (≤ 1 h for viewers other than the owner and anonymous) | Low | Same behaviour as core's like counts |
| Full index on `posts.actionable_count` (write cost on the hottest table) | Low | Consider replacing with a partial index (`WHERE actionable_count > 0`) after checking report usage |
| Daily limit can be exceeded by parallel requests on different posts (check before, record after success) | Low | Overshoot is at most the number of concurrent requests |
| `like_created` clears summary caches slightly before core updates like stats; a summary request in that window caches the old like count for up to an hour | Very low | Same staleness as core without the plugin |

## Operational requirements

- Discourse ≥ 2026.5.0. PostgreSQL ≥ 13 (uses `MATERIALIZED` CTEs). Redis.
- Post-deploy migrations must run (user deletion depends on them on existing sites).
- Sidekiq scheduler running (daily cleanup job, core directory refresh).

## Scaling characteristics

Measured (PostgreSQL 16, 1,020,000 `user_actions`, 20,000 actionable):

| Operation | Before | After |
| --- | --- | --- |
| Directory refresh, per column, all-time period | 380–454 ms, full table scan | ~50 ms, reads actionable rows only |
| Directory refresh, per column, weekly period | ~400 ms | ~10 ms |
| Migration 3 rows written | 200,000 (every post, twice) | 9,495 (affected posts only) |

From code analysis, not load-tested:

- **Topic rendering:** previously about 6 extra queries per post for signed-in
  viewers. Now none per post inside a topic view, and one lookup when a single
  post is serialized.
- **Mark/unmark:** one Redis lock per post plus one short transaction (about 6
  writes). Requests for the *same* post are serialized. Different posts proceed
  in parallel. A very hot post (many users marking within the same seconds)
  queues briefly on its lock.
- **Summary cache invalidation:** one Redis `DEL` with
  `2 users × 2 viewers × locales × 2` keys per mark and per like (392 keys with
  core's 49 locales). It is a single round trip, but it runs on every like in
  the forum.
- **Directory refresh:** cost now scales with the number of actionable
  `user_actions` in the period, not with the whole table.
- **`actionable_daily`:** bounded to about 90 days × active markers.
- **Who-actioned:** one `COUNT` plus up to 50 rows per request; no caching.

No load test was run. To size a large site, replay production-like traffic on
`POST/DELETE /actionable/:id` and topic views with `ab`/`k6` against staging, and
watch `pg_stat_statements` and Redis latency.

## Monitoring

- HTTP status rates for `/actionable/*`: a sustained 422 (`create_failed`) or
  503 rate indicates a problem; 429s show the daily limit at work.
- Sidekiq: failures of `CleanupActionableDaily` and of the directory refresh jobs.
- PostgreSQL: duration of the directory refresh statements (`pg_stat_statements`).
- Redis: availability (locks, rate limits, cache and MessageBus all depend on it).

## Recovery

- Counters: `rake actionable:recalculate_stats`, which is idempotent.
- Missing activity rows: `rake actionable:backfill_user_actions`.
- Code rollback: pin to `ce2c228` (see `DEPLOYMENT.md`). The schema changes are
  compatible with the old code.

## Recommended next engineering priorities

1. Decide on and add a LICENSE file.
2. Replace `index_posts_on_actionable_count` with a partial index (F-37).
3. Add a Data Explorer or admin report for `actionable_daily`, or drop the table
   if nobody uses it.
4. Optionally re-sync `user_stats.actionable_*` from directory data during the
   all-time refresh, as core does for likes, to make the counters self-healing.
