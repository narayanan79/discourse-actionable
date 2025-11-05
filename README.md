# Discourse Actionable Plugin

A Discourse plugin that adds an "actionable" button next to the like button, allowing users to mark posts as requiring action.

## Features

- **Actionable Button**: Check-style button with three states:
  - Outline check square (not actioned)  
  - Solid check square (actioned)
  - Colored solid when user has actioned
- **Count Display**: Shows number of users who marked the post as actionable
- **Who Actioned**: Click count to see avatars of users who marked as actionable
- **Real-time Updates**: Live updates via MessageBus when others act
- **Rate Limiting**: Configurable daily limits per user
- **Trust Level Control**: Minimum trust level requirements
- **Mobile Responsive**: Works on all screen sizes
- **Accessibility**: Full keyboard navigation and screen reader support

## Installation

1. Clone this repository into your Discourse plugins directory:
   ```bash
   cd plugins
   git clone https://github.com/discourse/discourse-actionable.git
   ```

2. Rebuild Discourse:
   ```bash
   ./launcher rebuild app
   ```

## Configuration

The plugin adds several site settings under Admin > Settings > Plugins:

- **actionable_enabled**: Enable/disable the actionable feature (default: true)
- **actionable_max_per_day**: Maximum actionable actions per user per day (default: 50)
- **actionable_min_trust_level**: Minimum trust level to use actionable (default: 0)
- **actionable_show_who_actioned**: Show who marked posts as actionable (default: true)

## Architecture

### Backend Components

- **ActionableActionCreator**: Service object for creating actionable actions
  - Uses Discourse's Service::Base framework
  - Handles permissions, rate limiting, and validations
  - Event-driven architecture (triggers :post_action_created events)
- **ActionableActionDestroyer**: Service object for removing actionable actions
  - Validates user permissions before removal
  - Maintains data consistency through event listeners
- **ActionableDaily**: Model for tracking daily action limits
  - Prevents abuse through per-user daily quotas
  - Automatic cleanup of old records
- **ActionableController**: API endpoints for actionable operations
  - RESTful design with proper error handling
  - Uses Guardian for authorization
- **Post Action Type**: New post action type (ID: 50) for actionable
  - Integrated with Discourse's existing post action system

### Frontend Components

- **ActionableButton**: Main button component with animations
  - Glimmer component with full JSDoc documentation
  - Optimistic UI updates for instant feedback
  - MessageBus integration for real-time updates
  - Proper loading and disabled states
- **ActionableCount**: Count display and user list component
  - Shows actionable count and user avatars
  - Click-to-expand user list with accessibility support
- **Post Menu Integration**: Seamless integration with existing post controls
  - Uses Discourse's post-menu-buttons value transformer
  - Positioned before reply, share, and flag buttons
- **Icon System**: Bullseye icon for actionable actions

### Database Tables

- **actionable_daily**: Tracks daily action counts per user
  - Indexed on user_id and actionable_date for fast queries
  - Unique constraint prevents duplicate entries
- **posts.actionable_count**: Denormalized count for performance
  - Updated via event listeners to avoid N+1 queries
  - Indexed for efficient sorting and filtering
- **post_actions**: Uses existing table with actionable post action type
  - Leverages Discourse's built-in post action infrastructure
- **user_stats**: Extended with actionable_given and actionable_received columns
- **directory_items**: Includes actionable statistics for user directory

## API Endpoints

- `POST /actionable/:post_id` - Mark post as actionable
- `DELETE /actionable/:post_id` - Remove actionable from post  
- `GET /actionable/:post_id/who` - Get users who actioned the post

## Events

The plugin triggers Discourse events that other plugins can listen to:

- `actionable_created` - When a post is marked as actionable
- `actionable_destroyed` - When actionable is removed from a post

## Styling

The plugin includes comprehensive CSS with support for:

- Dark mode
- High contrast mode  
- Mobile responsive design
- Animation effects
- Accessibility focus styles

## Code Quality

This plugin follows Discourse best practices and coding standards:

- ✅ **Zero RuboCop offenses** - All Ruby code passes strict linting
- ✅ **Full JSDoc documentation** - Complete inline documentation for all JavaScript components
- ✅ **Service-based architecture** - Uses Discourse's Service::Base framework
- ✅ **Event-driven design** - Single source of truth via event listeners
- ✅ **Performance optimized** - Denormalized counts, indexed queries, no N+1 issues
- ✅ **Security hardened** - Guardian integration, rate limiting, input validation
- ✅ **Accessibility compliant** - ARIA labels, keyboard navigation support

## Testing

Run the plugin tests:

```bash
bundle exec rspec plugins/discourse-actionable/spec
```

The plugin includes comprehensive test coverage:
- Service object specs (ActionableActionCreator, ActionableActionDestroyer)
- Controller specs with error handling
- Model specs for ActionableDaily
- System specs for UI interactions
- Integration tests for real-time updates

## License

MIT License - see LICENSE file for details.

## Development

### Starting the Development Environment

```bash
# Start Rails server
RAILS_ENV=development bin/rails server -p 3000 -b 0.0.0.0

# Start Ember server (in another terminal)
pnpm ember s --proxy http://localhost:3000
```

Access the application at http://localhost:4200

### Code Style

This plugin follows Discourse coding standards:
- Run `bundle exec rubocop -A` to auto-fix Ruby linting issues
- Add JSDoc comments to all JavaScript classes, methods, and getters
- Follow the service object pattern for business logic
- Use event listeners in plugin.rb for cross-cutting concerns

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass and code is linted
6. Submit a pull request

### Pull Request Checklist

- [ ] All RuboCop offenses resolved (`bundle exec rubocop`)
- [ ] JSDoc comments added for new JavaScript code
- [ ] Tests added and passing (`bundle exec rspec`)
- [ ] No console.log or debug statements in production code
- [ ] README updated if adding new features

## Companion Plugin

This plugin works great alongside the **discourse-insightful** plugin, which allows users to mark posts that provide valuable insights. Together, they provide a comprehensive system for community-driven content curation.