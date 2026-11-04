# Security

## Threat model

The plugin lets signed-in users create small records (a mark on a post) and
read aggregate data about other users (counts, "who marked"). The assets to
protect are:

- the **visibility rules** of private categories and private messages;
- **user privacy** settings (`enable_names`, ignored users);
- the **integrity** of counters shown to the community.

Admin-only configuration consists of four site settings. The plugin makes no
outbound network calls and stores no secrets.

## Controls

| Risk | Control |
| --- | --- |
| Acting on posts the user cannot see | `Guardian#can_mark_post_actionable?` requires `can_see_post?`. The 403 response carries no post data. |
| Bypassing the rules through core's `/post_actions` | `PostActionsControllerExtension` rejects post action type 50 with 403, even while the plugin is disabled. |
| Reading who marked a hidden post | `who_actioned` calls `guardian.ensure_can_see!`, is gated by `actionable_show_who_actioned`, and requires login. |
| Reading who marked a post through core | Core's `/post_action_users` lists the actors of unknown types to anyone who can see the post. `PostActionUsersControllerExtension` rejects type 50 with 403. |
| Learning who marked a post from real-time messages | The `actioned`/`unactioned` MessageBus payload includes `actioned_by` only when `actionable_show_who_actioned` is on. |
| Leaking names | Summary lists use core's `UserWithCountSerializer` (`enable_names`). The who-actioned list uses `BasicUserSerializer` with the guardian scope. |
| Leaking real-time updates | `Post#publish_change_to_clients!` restricts messages to the topic's secure audience. |
| Abuse and flooding | Daily `RateLimiter` (successful marks only; staff are exempt). Core's per-post limit of 4/min applies. Trust-level gate. |
| CSRF | Standard Rails/Discourse CSRF protection. All state changes use POST or DELETE. |
| SQL injection | SQL uses bind parameters. The only interpolated values are integer constants and column names validated against an allow-list (`DirectoryColumns::NAMES`). |
| XSS | Templates use escaped `{{}}` output. The only trusted HTML is the activity empty-state body, built from a locale string and a core icon. |
| Concurrency abuse (double submits) | A per-post `DistributedMutex` plus a transaction; duplicates are refused with 422. |
| Counter tampering through partial failures | All writes share one transaction; failures roll back and are reported, not swallowed. |

## Residual risks

- **Identifier collisions:** another third-party plugin using post action type
  50 or user action types 18/19 would mix data. There is no runtime detection.
- **Visibility oracle:** the endpoints answer 403 for posts that exist but are
  hidden and 404 for posts that do not exist. Core's own post-action endpoints
  behave the same way.
- **Per-viewer summary cache:** after a change, viewers other than the owner and
  anonymous users can see stale counts for up to an hour. These are counts only,
  so no permissions are affected.

## Reporting a vulnerability

Please report security issues privately to the maintainer through GitHub
(https://github.com/narayanan79/discourse-actionable) rather than in a public
issue.

## Secret scan

A pattern scan of the working tree and of every added line in the git history
(39 commits) found no credentials (see `BASELINE_REPORT.md` §3.4).
