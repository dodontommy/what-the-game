# System Architecture

## Overview

What The Game is built as a modern Rails 8 application with a service-oriented architecture, designed for scalability and AI integration.

## Architecture Principles

1. **AI-First Design**: Every feature considers AI enhancement opportunities
2. **Service-Oriented**: Business logic encapsulated in service objects
3. **Platform Agnostic**: Unified interface for all gaming platforms
4. **Async Processing**: Background jobs for API calls and AI operations
5. **Cache-Heavy**: Aggressive caching for external API responses
6. **API-Ready**: RESTful API design for future mobile/desktop clients

---

## System Components

### 1. Application Layer

#### Models (Domain Objects)

**User**
- Core user entity
- Associations: games (through user_games), game_services, recommendations
- Future: preferences, settings, friend relationships

**Game**
- Represents a video game across all platforms
- Normalized game data from multiple sources
- Attributes: title, description, platform, genre, developer, publisher
- Future: metacritic_score, tags, screenshots, videos

**UserGame** (Join Model)
- User's relationship with a specific game
- Tracks: status, hours_played, completion_percentage, priority
- Status values: backlog, playing, completed, abandoned, wishlist
- Future: custom_tags, rating, review, achievements

**GameService**
- OAuth connection to gaming platforms
- Stores encrypted access tokens
- Handles token refresh
- Platforms: steam, gog, epic (extensible)

**Recommendation**
- AI-generated game recommendation
- Links user to game with score and reasoning
- Tracks AI model used for quality analysis
- Versioned for A/B testing different prompts

#### Controllers

**HomeController**
- Landing page and dashboard
- User stats overview
- Recent recommendations

**GamesController**
- Game library browsing
- Search and filtering
- Game details

**UserGamesController**
- Backlog management
- Status updates
- Progress tracking

**RecommendationsController**
- View recommendations
- Generate new recommendations
- Feedback collection

**Future Controllers:**
- **UsersController**: Registration, profile management
- **SessionsController**: Authentication
- **OauthController**: Platform OAuth callbacks
- **ApiController**: Base for API endpoints
- **AnalyticsController**: Gaming insights and statistics
- **SocialController**: Friend management and social features

### 2. Service Layer

#### AI Services

**AiServices::RecommendationService**
- Core AI recommendation engine
- Integrates with OpenAI GPT-4 or Anthropic Claude
- Methods:
  - `generate_recommendations(limit:, context:)` - Generate N recommendations
  - `recommend_game(game)` - Evaluate specific game
  - `explain_recommendation(game, user)` - Why this game?
  - `natural_query(query)` - Process natural language questions

**AiServices::InsightService** *(Planned)*
- Analyzes user gaming patterns
- Generates insights and statistics
- Methods:
  - `analyze_gaming_habits` - Pattern analysis
  - `predict_next_game` - What will user play next?
  - `calculate_backlog_impact` - Backlog completion estimates

**AiServices::ConversationService** *(Planned)*
- Chatbot interface for game discovery
- Maintains conversation context
- Natural language game queries

#### Platform Services

**GamePlatforms::BasePlatform**
- Abstract base class
- Standard interface for all platforms
- Methods:
  - `fetch_library` - Get user's game list
  - `fetch_game_details(game_id)` - Get game metadata
  - `fetch_playtime(game_id)` - Get play hours
  - `configured?` - Check if API keys present

**GamePlatforms::SteamPlatform**
- Steam Web API integration
- Endpoints:
  - `IPlayerService/GetOwnedGames` - User library
  - `ISteamUserStats/GetPlayerAchievements` - Achievements
  - `ISteamUserStats/GetSchemaForGame` - Game metadata
- Uses Steam API key (no OAuth)

**GamePlatforms::GogPlatform**
- GOG Galaxy API integration
- OAuth 2.0 flow
- Endpoints:
  - `/account/getFilteredProducts` - User library
  - `/products/{id}` - Game details

**GamePlatforms::EpicPlatform**
- Epic Games Store API
- OAuth 2.0 flow
- Endpoints:
  - `/epic/oauth/v1/token` - OAuth
  - `/launcher/api/public/assets/Windows` - Library

**GamePlatforms::IgdbService** *(Planned)*
- IGDB (Internet Game Database) integration
- Rich game metadata
- Cover art, screenshots, videos
- Game relationships (DLC, expansions, remasters)

**GamePlatforms::RawgService** *(Planned)*
- RAWG Video Games Database
- Alternative game metadata source
- User reviews and ratings
- Screenshots and media

#### Data Services

**DataServices::GameNormalizer** *(Planned)*
- Normalizes game data from multiple sources
- Handles duplicate detection
- Merges metadata from different APIs

**DataServices::SyncService** *(Planned)*
- Orchestrates platform library syncing
- Batch processing of game imports
- Handles rate limiting and retries

**DataServices::CacheService** *(Planned)*
- Manages external API response caching
- Cache invalidation strategies
- TTL management

#### Analytics Services

**AnalyticsServices::StatsCalculator** *(Planned)*
- Calculates user statistics
- Gaming time analysis
- Completion rates
- Genre preferences

**AnalyticsServices::TrendAnalyzer** *(Planned)*
- Identifies gaming patterns
- Seasonal trends
- Peak gaming times

---

## Data Architecture

### Database Schema

```sql
-- Users Table
CREATE TABLE users (
  id BIGSERIAL PRIMARY KEY,
  email VARCHAR NOT NULL UNIQUE,
  username VARCHAR NOT NULL,
  password_digest VARCHAR, -- Future: authentication
  preferences JSONB, -- User preferences for AI
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

-- Games Table
CREATE TABLE games (
  id BIGSERIAL PRIMARY KEY,
  title VARCHAR NOT NULL,
  description TEXT,
  platform VARCHAR NOT NULL, -- 'steam', 'gog', 'epic', etc.
  external_id VARCHAR NOT NULL, -- Platform-specific ID
  release_date DATE,
  genre VARCHAR,
  developer VARCHAR,
  publisher VARCHAR,
  metadata JSONB, -- Flexible metadata storage
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  UNIQUE(platform, external_id)
);

-- User Games (Backlog) Table
CREATE TABLE user_games (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id),
  game_id BIGINT NOT NULL REFERENCES games(id),
  status VARCHAR NOT NULL, -- 'backlog', 'playing', 'completed', etc.
  hours_played DECIMAL(10,2),
  completion_percentage INTEGER,
  priority INTEGER, -- 1-10
  notes TEXT,
  custom_tags VARCHAR[], -- Array of custom tags
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  UNIQUE(user_id, game_id)
);

-- Game Services (OAuth Connections) Table
CREATE TABLE game_services (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id),
  service_name VARCHAR NOT NULL, -- 'steam', 'gog', 'epic'
  access_token TEXT, -- Encrypted
  refresh_token TEXT, -- Encrypted
  token_expires_at TIMESTAMP,
  external_user_id VARCHAR, -- Platform's user ID
  last_synced_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  UNIQUE(user_id, service_name)
);

-- Recommendations Table
CREATE TABLE recommendations (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id),
  game_id BIGINT NOT NULL REFERENCES games(id),
  score DECIMAL(3,2), -- 0.00 - 1.00
  reason TEXT,
  ai_model VARCHAR, -- 'gpt-4', 'claude-3', etc.
  prompt_version INTEGER, -- For A/B testing
  context JSONB, -- Context used for recommendation
  user_feedback INTEGER, -- 1-5 rating, null if not rated
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

-- Future Tables
-- friend_relationships, game_sessions, achievements, 
-- user_preferences, gaming_insights, etc.
```

### Indexing Strategy

```sql
-- Performance indexes
CREATE INDEX idx_games_platform_external ON games(platform, external_id);
CREATE INDEX idx_user_games_user_status ON user_games(user_id, status);
CREATE INDEX idx_user_games_priority ON user_games(priority DESC);
CREATE INDEX idx_recommendations_user_score ON recommendations(user_id, score DESC);
CREATE INDEX idx_game_services_user ON game_services(user_id, service_name);

-- Full-text search (Future)
CREATE INDEX idx_games_title_search ON games USING GIN(to_tsvector('english', title));
CREATE INDEX idx_games_description_search ON games USING GIN(to_tsvector('english', description));
```

---

## AI Integration Architecture

### AI Service Selection

**Primary Options:**
1. **OpenAI GPT-4**
   - Pros: Excellent reasoning, large context window, reliable
   - Cons: Cost, rate limits
   - Best for: Complex recommendations, natural language queries

2. **Anthropic Claude 3 (Sonnet/Opus)**
   - Pros: Great reasoning, longer context, competitive pricing
   - Cons: Newer, less ecosystem support
   - Best for: Detailed analysis, conversation

**Strategy**: Support both, allow configuration, enable A/B testing

### AI Prompt Engineering

**Recommendation Prompt Structure:**
```
System: You are a gaming expert AI assistant helping users find their next game.

Context:
- User's gaming history: [summarized data]
- Favorite genres: [list]
- Average session length: [time]
- Completion rate: [percentage]
- Current backlog: [titles]

User's Current Situation:
- Available time: [hours]
- Current mood: [relaxing/challenging/story-driven/etc.]
- Recently played: [titles]

Task: Recommend 5 games from the user's backlog, ranked by match score.

Output Format (JSON):
{
  "recommendations": [
    {
      "game_id": <id>,
      "title": "<title>",
      "match_score": <0.0-1.0>,
      "reasoning": "<why this game?>",
      "estimated_playtime": "<hours>",
      "tags": ["<tag1>", "<tag2>"]
    }
  ],
  "summary": "<overall recommendation summary>"
}
```

### AI Response Processing

1. **Streaming Response**: Stream AI responses for better UX
2. **Validation**: Ensure JSON structure, validate game references
3. **Fallbacks**: Handle API errors gracefully
4. **Caching**: Cache recommendations for 24 hours
5. **Logging**: Log prompts and responses for quality analysis

---

## External API Integration

### API Rate Limiting Strategy

| Service | Rate Limit | Strategy |
|---------|-----------|----------|
| Steam API | 100,000/day | Cache aggressively, batch requests |
| GOG API | Variable | Respect rate limit headers |
| Epic API | Unknown | Conservative approach, monitor |
| OpenAI | Tier-based | Queue requests, retry with backoff |
| Anthropic | Tier-based | Queue requests, retry with backoff |

### Caching Strategy

**Cache Layers:**
1. **Application Cache** (Solid Cache)
   - API responses: 24 hours
   - Game metadata: 7 days
   - User libraries: 6 hours
   
2. **Database Cache**
   - Materialized views for analytics
   - Precomputed statistics
   
3. **Future: Redis**
   - Session storage
   - Real-time features
   - Job queues

### Error Handling

**Retry Strategy:**
```ruby
def fetch_with_retry(max_retries: 3, backoff: 2)
  retries = 0
  begin
    yield
  rescue APIError => e
    retries += 1
    if retries <= max_retries
      sleep(backoff ** retries)
      retry
    else
      log_error(e)
      raise
    end
  end
end
```

---

## Background Job Architecture

**Job Types:**

1. **Sync Jobs** (Solid Queue)
   - `SyncSteamLibraryJob` - Sync user's Steam library
   - `SyncGogLibraryJob` - Sync GOG library
   - `SyncEpicLibraryJob` - Sync Epic library
   - Scheduled: Every 6 hours or on-demand

2. **AI Jobs**
   - `GenerateRecommendationsJob` - Create recommendations
   - `AnalyzeGamingHabitsJob` - Generate insights
   - `UpdateGameMetadataJob` - Enrich game data
   - Triggered: On-demand or scheduled

3. **Maintenance Jobs**
   - `CleanupOldRecommendationsJob` - Remove old recs
   - `RefreshGameMetadataJob` - Update game info
   - `CalculateUserStatsJob` - Precompute statistics
   - Scheduled: Daily

**Queue Priority:**
1. **Critical**: User-facing operations
2. **High**: On-demand syncs
3. **Normal**: Scheduled syncs
4. **Low**: Maintenance tasks

---

## Security Architecture

### API Key Management

- **Storage**: Environment variables (`.env`)
- **Encryption**: Encrypted at rest for OAuth tokens
- **Rotation**: Support for key rotation without downtime
- **Auditing**: Log all API key usage

### Data Security

1. **OAuth Tokens**: Encrypted using ActiveRecord encryption
2. **User Data**: GDPR compliance considerations
3. **API Keys**: Never logged or exposed
4. **Rate Limiting**: Prevent abuse

### Future Considerations

- OAuth for user authentication
- API token authentication for mobile apps
- CSRF protection (Rails default)
- SQL injection prevention (parameterized queries)
- XSS prevention (Rails default escaping)

---

## Scalability Considerations

### Current Architecture (Phase 1)
- Monolithic Rails app
- Single PostgreSQL database
- Solid Cache/Queue/Cable (SQLite-backed)
- Suitable for: 1-10K users

### Future Scaling (Phase 2+)

**Horizontal Scaling:**
- Multiple Rails app servers
- Load balancer (nginx/HAProxy)
- Separate job workers

**Database Scaling:**
- Read replicas for analytics
- Connection pooling (PgBouncer)
- Partitioning for large tables

**Caching:**
- Separate Redis cluster
- CDN for static assets
- Fragment caching for views

**Microservices (If Needed):**
- AI Service: Dedicated service for AI operations
- Sync Service: Platform syncing
- Analytics Service: Data analysis and insights

---

## Deployment Architecture

### Docker Container Structure

```
┌─────────────────────────────────────┐
│         Docker Container            │
│                                     │
│  ┌──────────────────────────────┐  │
│  │     Rails Application        │  │
│  │     (Puma Web Server)        │  │
│  └──────────────────────────────┘  │
│                                     │
│  ┌──────────────────────────────┐  │
│  │   Solid Queue Worker         │  │
│  │   (Background Jobs)          │  │
│  └──────────────────────────────┘  │
│                                     │
│  ┌──────────────────────────────┐  │
│  │   Solid Cable (WebSockets)   │  │
│  └──────────────────────────────┘  │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│      PostgreSQL Container           │
│      (Persistent Storage)           │
└─────────────────────────────────────┘
```

### Deployment Strategy (Kamal)

- **Zero-downtime deploys**
- **Health checks** before traffic routing
- **Rollback capability**
- **Environment-based configuration**
- **Secrets management**

---

## Monitoring & Observability

### Logging Strategy

**Log Levels:**
- **INFO**: User actions, API calls
- **WARN**: Rate limits, slow queries
- **ERROR**: Exceptions, failed jobs
- **DEBUG**: Development details

**Log Aggregation (Future):**
- Centralized logging (e.g., Papertrail, Logstash)
- Error tracking (Sentry, Honeybadger)
- Performance monitoring (New Relic, Scout)

### Metrics to Track

**Application Metrics:**
- Request rate and latency
- Error rate by endpoint
- Background job queue size
- Cache hit rate

**Business Metrics:**
- Daily active users
- Games synced per day
- Recommendations generated
- User satisfaction (feedback ratings)

**AI Metrics:**
- AI API latency
- Token usage and costs
- Recommendation acceptance rate
- Prompt effectiveness

---

## Testing Strategy

### Test Pyramid

```
    /\
   /  \    E2E Tests (Minimal)
  /────\   System tests for critical flows
 /      \  
/────────\ Integration Tests (Moderate)
           Service tests, controller tests

────────── Unit Tests (Majority)
           Models, services, helpers
```

### Test Coverage Goals

- **Models**: 100% coverage
- **Services**: 95% coverage
- **Controllers**: 90% coverage
- **Overall**: 90%+

### Testing Tools

- **Minitest**: Rails default
- **FactoryBot**: Test data
- **VCR**: API mocking
- **WebMock**: HTTP stubbing
- **Capybara**: System tests

---

## Development Workflow

### Git Branching Strategy

```
main (production)
  └── develop (staging)
       ├── feature/ai-recommendations
       ├── feature/steam-integration
       ├── feature/user-auth
       └── bugfix/cache-issue
```

### CI/CD Pipeline

**GitHub Actions Workflow:**
1. Lint (RuboCop)
2. Security scan (Brakeman, bundler-audit)
3. Run tests
4. Build Docker image
5. Deploy to staging (auto)
6. Deploy to production (manual approval)

---

## Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| Page Load | < 200ms | Server-side rendering |
| API Response | < 100ms | Cached responses |
| AI Recommendation | < 5s | Streaming for better UX |
| Library Sync | < 30s | For ~500 games |
| Database Query | < 50ms | 95th percentile |
| Background Job | < 5min | For sync jobs |

---

## Future Architectural Considerations

1. **GraphQL API**: More flexible than REST for mobile clients
2. **Event Sourcing**: For audit trails and analytics
3. **CQRS**: Separate read/write models for performance
4. **Real-time Features**: WebSocket-based live updates
5. **Mobile Apps**: Native iOS/Android clients
6. **Desktop App**: Electron-based desktop client
7. **Browser Extension**: In-browser game tracking

---

**Document Version**: 1.0  
**Last Updated**: 2026-01-14  
**Status**: Living Document
