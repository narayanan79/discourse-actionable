# Baseline report

This report records the state of the repository **before any change** was made
during the 2026-11-04 engineering audit. It separates what was actually executed
from what was established by reading source code.

| Item | Value |
| --- | --- |
| Repository | `narayanan79/discourse-actionable` |
| Baseline commit | `ce2c228444c427e07c405165c02c1fae45de201a` (2026-08-19, "Remove invalid .discourse-compatibility file") |
| Reference Discourse core | `discourse/discourse@b7d63fa` (`2026.11.0-latest`, 2026-11-04), Rails 8.1.4, requires Ruby `~> 4.0.0` |
| Container | Ubuntu 24.04, PostgreSQL 16.15, Redis 7.0.15, Node 22.23, pnpm 10.28, Ruby 3.3.6 (system) |

## 1. Environment limitations (read this first)

A Discourse plugin cannot be tested on its own: RSpec, QUnit, linting and
asset builds all run inside a Discourse core checkout with its full Ruby and
JavaScript dependency trees installed.

| Step | Result | Evidence |
| --- | --- | --- |
| Clone Discourse core (`git clone --depth 1`) | **Done** | `b7d63fa`, 27,731 files |
| Install Ruby 4.0 (core requirement) | **Done** | `cache.ruby-lang.org` is blocked by the network policy (HTTP 403 from the egress proxy), so Ruby **4.0.9** was compiled from the official `ruby/ruby` git tag `v4.0.9` into `/opt/rbenv/versions/4.0.9` |
| Start PostgreSQL 16 and Redis 7 | **Done** | `pg_isready` → accepting connections; `redis-cli ping` → `PONG` |
| `bundle install` for Discourse core | **Blocked** | Denied by the session's auto-mode permission classifier ("Code from External"): it would download and execute native-extension build code from ~300 third-party gems. Not worked around. |
| `pnpm install` for Discourse core | **Not attempted** | Same category of action as above |
| Docker (`discourse/discourse_test` image) | **Unavailable** | Docker daemon not running (`/var/run/docker.sock` missing); pulling the image would also be external code |

**Consequence:** none of the plugin's RSpec specs, QUnit tests, RuboCop /
syntax_tree / ESLint / Prettier / Stylelint linters, migrations-under-Rails, or
the Ember asset build could be executed. Nothing in this report or in
`ENGINEERING_FINDINGS.md` claims those passed or failed at runtime.

## 2. What was executed

### 2.1 Ruby syntax (Ruby 4.0.9 / Prism parser)

`ruby -wc` over every tracked `*.rb` and `*.rake` file (21 files).

| Result | Detail |
| --- | --- |
| Exit code 0 for 21/21 files | All files parse |
| 1 warning | `spec/lib/actionable_action_destroyer_spec.rb:104: assigned but unused variable - staff_action` |

### 2.2 YAML and i18n consistency (stdlib-only script)

`check_i18n.rb` (a self-written checker that uses only Ruby's standard library) parses every `config/**/*.yml` file. It then checks that every site setting has a `site_settings.*` translation and that every i18n key referenced from JavaScript or Ruby exists.

| Result | Detail |
| --- | --- |
| `config/settings.yml`, `client.en.yml`, `server.en.yml` | Parse OK |
| Missing translations | None found (exit code 0) |
| Note | Controller error messages are hard-coded English strings, so this check cannot see them. See `ENGINEERING_FINDINGS.md` F-24. |

### 2.3 JavaScript syntax (approximation)

`check_js.rb` runs `node --check` on the 7 plain `.js` files. For the 5 `.gjs` files it first strips `<template>` blocks and decorators, then checks what remains.

| Result | Detail |
| --- | --- |
| 12/12 files OK | Structural JS syntax is valid |
| Negative control | A deliberately broken `.gjs` (missing `}`) was correctly rejected with exit code 1 |
| Limitation | Templates are not validated; this is **not** a substitute for ESLint, Prettier or ember-template-lint |

### 2.4 Plugin SQL against real PostgreSQL 16

A scratch database was built from core table definitions: column names, types and indexes were copied from the `== Schema Information` annotations in core's models. The plugin's migrations were applied as the SQL Rails emits, with migration 3's data statements copied verbatim. The database was then seeded with 5,000 users, 20,000 topics (10% PMs), 100,000 posts, 1,020,000 `user_actions` (20,000 of them actionable) and 10,000 actionable `post_actions`.

| Check | Result |
| --- | --- |
| Migration DDL (`create_table`, `add_column`, `add_index`) | Applies cleanly |
| Migration `20250101000003` with a legacy `post_custom_fields.value = ''` | **Fails:** `ERROR: invalid input syntax for type integer: ""` (the migration aborts) |
| Migration `20250101000003` on clean data | Each of its two `UPDATE`s rewrote **100,000 of 100,000** `posts` rows (200,000 row versions in one transaction), although only 9,495 posts have an actionable |
| Directory column SQL (`plugin.rb`), `all` period | `Seq Scan on user_actions` reading **all 1,020,000 rows** for each column; 380–454 ms per column (4 runs). Two columns × six periods means 12 full scans per directory refresh |
| Directory results snapshot | Saved for all 6 periods to compare against the rewritten query |

### 2.5 Duplicate-index check

The DDL generated from migrations `…0001` and `…0007` creates two identical
unique indexes on `actionable_daily (user_id, actionable_date)`:
`index_actionable_daily_on_user_id_and_date` and
`index_actionable_daily_on_user_and_date`.

## 3. What could not be executed, and the static evidence instead

The existing tests were read line by line against the core source at
`b7d63fa`. Each claim below cites the core code that contradicts the test.
These are **predicted** failures, not observed ones.

### 3.1 RSpec (`spec/`, 7 files)

| File | Why it cannot pass (core evidence) |
| --- | --- |
| `spec/controllers/actionable_controller_spec.rb` | `fab!(:post)` defines a `post` helper that shadows RSpec's `post :create, params:` request helper, so every `post :create` call goes to the fabricator. The spec also expects keys and statuses the controller never returns: `can_undo_actionable`, 422 for a duplicate (the policy returns 403), and 422 when disabled (the controller raises `NotFound`, i.e. 404). It calls services as `ActionableActionCreator.call(guardian:, post:)` without the `params:` key that `Service::Base` contracts read. |
| `spec/lib/actionable_action_creator_spec.rb` | Calls the service as `call(post_id:, user:, guardian:)`, but the contract reads `params.post_id`, so the contract fails. Uses `PostAction.act`, which does not exist in core (no `def self.act` in `app/models/post_action.rb`). Uses `PostActionType.types[:actionable]`, which is `nil` because `PostActionTypeView#types` is rebuilt from the `flags` table on every call (`lib/post_action_type_view.rb:35-40`). Expects a MessageBus payload `user_id: user.id`, but the code sends `actioned_by`. |
| `spec/lib/actionable_action_destroyer_spec.rb` | Same `PostAction.act` and `call(post_id:)` problems. Expects `StaffActionLogger#log_post_action`, which the code never calls. |
| `spec/models/actionable_daily_spec.rb` | Uses attributes `count`/`date`; the table columns are `actionable_count`/`actionable_date`. |
| `spec/services/actionable_action_creator_spec.rb` | Calls `call(guardian:, post:)` without `params:`, so the contract fails. Expects `result.post_action`, which is never put in the context. |
| `spec/services/actionable_action_destroyer_spec.rb` | Same calling convention. Expects an admin to remove *another user's* action; the service only ever looks up the acting user's own action. Expects `post_action.update!(created_at: 1.year.ago)` to remain undoable, but core's `can_delete_post_action?` enforces `post_undo_action_window_mins` (default 10). |
| `spec/system/actionable_button_spec.rb` | Expects `.d-icon-far-check-square` / `.d-icon-check-square`; the component renders `bullseye`. Uses `PostAction.act`. Uses `page.driver.browser.url_blacklist`, which the Playwright driver core uses for system specs does not provide. |

**Predicted baseline:** the large majority of examples error or fail. There is
no CI workflow in the repository that would have shown this. The README's
"comprehensive test coverage" and "Zero RuboCop offenses" claims are not
backed by any configuration or pipeline in the repository.

### 3.2 QUnit (`test/javascripts/`, 2 files)

| File | Why it cannot pass |
| --- | --- |
| `acceptance/actionable-button-test.js` | Stubs `/t/1.json` with a 1-post payload that lacks most topic fields core needs to render a topic. Asserts icons (`far-square-check`, `square-check`) that the component never renders. Asserts `.actionable-count` hides at 0 and `can_undo_actionable` driven states that the component does not use. |
| `unit/components/actionable-button-test.js` | Renders `<ActionableButton>` through `hbs` without importing it (a plugin component is not resolvable that way). Uses a global `sinon` and asserts `messageBus.subscribe.called` without a spy. Asserts the same non-existent icons. The `shouldRender` test asserts `true` for a post with `show_actionable: false, actionable_count: 0`, which contradicts the implementation. |

### 3.3 Linting, formatting, type checks, asset build

There are no linter configurations (`.rubocop.yml`, `eslint.config.mjs`,
`.prettierrc`, `stylelint.config.mjs`), no `package.json` or `Gemfile`, and no CI
workflow. These checks could not be run (see §1) and have no baseline.

### 3.4 Security and dependency scanning

The plugin has no direct dependencies: no `Gemfile` and no `package.json`. Its
dependency surface is Discourse core, so a dependency audit belongs to core's
pipeline.

Secret scan (executed): a case-insensitive regex for `api_key`, `secret`,
`password`, `private_key`, PEM private-key headers, AWS keys and common token
prefixes (`ghp_`, `xoxb-`, `sk-`) was run over the current tree (`git grep`)
and over every added line in the full history (`git log -p --all`, 39 commits).
**0 matches.**

## 4. Summary of the baseline

| Check | Baseline result |
| --- | --- |
| Ruby parse (21 files) | Pass (1 warning) |
| YAML parse / i18n coverage | Pass |
| JS structural syntax (12 files) | Pass (approximation) |
| Migration DDL on PostgreSQL 16 | Pass |
| Migration 3 data step | **Fails** on legacy blank values; full rewrite of `posts` ×2 |
| Directory SQL | Correct results, but 12 full `user_actions` scans per refresh |
| RSpec | **Not executable here**; statically predicted to fail broadly |
| QUnit | **Not executable here**; statically predicted to fail broadly |
| Lint / format / type check | **No configuration in repo**; not executable here |
| CI | **None present** |
