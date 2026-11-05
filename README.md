# Discourse Actionable

A Discourse plugin that adds an **Actionable** button next to the like button,
so members can mark someone else's post as "requiring action".

- Shows how many people marked a post, and who (optional).
- Updates in real time for everyone viewing the topic.
- Tracks "Actionable Given / Received" per user: profile stats, summary lists,
  activity tabs, and optional user-directory columns.

## Requirements

- Discourse **2026.5.0 or newer**. Older sites are pinned by
  `.discourse-compatibility` to the last commit that supported them.
- No extra services: the plugin uses Discourse's own PostgreSQL, Redis and
  Sidekiq.

## Installation

Add the plugin to your container definition (`containers/app.yml`) and rebuild:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/narayanan79/discourse-actionable.git
```

```bash
./launcher rebuild app
```

The rebuild runs the plugin's migrations and seed data. See
[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for upgrade notes, the post-deploy
migration, and the maintenance tasks.

## Configuration

Admin → Settings → Plugins:

| Setting | Default | Description |
| --- | --- | --- |
| `actionable_enabled` | `true` | Turns the feature on or off. Turning it off also hides the plugin's directory columns. |
| `actionable_max_per_day` | `50` | Successful marks allowed per user per day (staff are not limited). `0` blocks marking. |
| `actionable_min_trust_level` | `0` | Minimum trust level (0–4) needed to mark posts. |
| `actionable_show_who_actioned` | `true` | Signed-in users can see who marked a post. |

**Directory columns:** core creates plugin directory columns hidden. To show
"Actionable Given" and "Actionable Received", go to Admin → Users → Directory
columns. Turning the plugin off hides them, and turning it back on shows them again.

## Behaviour

- Members can't mark their own posts, or posts in topics that are closed, archived,
  deleted, or that they cannot see.
- A mark can be removed within core's `post_undo_action_window_mins` (10 minutes
  by default), like a like.
- Marks in private messages appear on the post but are not counted in profile stats
  or directory columns. This matches how core treats likes.
- Anonymous visitors who click the button are sent to the login page.
- Core's generic `/post_actions` and `/post_action_users` endpoints refuse this
  action type, so every mark and every "who marked" lookup goes through the
  plugin's rules.
- With `actionable_show_who_actioned` off, real-time updates carry only the new
  count, not who made the change.

## HTTP API

All endpoints need a signed-in user and return `404` when the plugin is disabled.

| Method | Path | Result |
| --- | --- | --- |
| `POST` | `/actionable/:post_id` | `200` with `{ success, actionable_count, actioned, acted, can_toggle_actionable, can_undo_actionable }`. `403` if not allowed, `404` if the post doesn't exist, `422` if already marked, `429` when the daily limit is reached, `503` in read-only mode. |
| `DELETE` | `/actionable/:post_id` | Same body. `403` after the undo window, `404` if the post wasn't marked. |
| `GET` | `/actionable/:post_id/who` | `{ users: [...], total_count }`, oldest first, at most 50 users. Users the viewer ignores are hidden. `403` if the post is not visible or the list is disabled. |

The plugin's own errors use `{ success: false, errors: ["…"] }`. The `429`,
the `503` and the disabled-plugin `404` come from Discourse core in its standard
error format (`{ errors: [...], error_type: ... }`).

## Events for other plugins

| Event | Arguments |
| --- | --- |
| `:actionable_created` | `post_action`, acting `user` |
| `:actionable_destroyed` | `post_action`, acting `user` |

The events fire after the database transaction commits.

## Maintenance tasks

```bash
./launcher enter app
rake actionable:recalculate_stats       # repair user_stats / posts counters
rake actionable:backfill_user_actions   # recreate missing activity rows
```

## Development

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) and [docs/TESTING.md](docs/TESTING.md).
Architecture notes are in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), and the
security model is in [docs/SECURITY.md](docs/SECURITY.md).

## Companion plugin

[discourse-insightful](https://github.com/narayanan79/discourse-insightful)
uses separate identifiers (post action type 51, user actions 20/21), so the two
plugins can run together.

## License

The project is intended to be MIT-licensed. Note that the repository does not
yet contain a `LICENSE` file.
