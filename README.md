# What The Game 🎮

**An AI-First Game Library Management & Discovery Platform**

> Unify your gaming libraries, get intelligent recommendations, and discover what to play next using cutting-edge AI technology.

[![Rails Version](https://img.shields.io/badge/Rails-8.1.2-red.svg)](https://rubyonrails.org/)
[![Ruby Version](https://img.shields.io/badge/Ruby-3.2.3-red.svg)](https://www.ruby-lang.org/)
[![License](https://img.shields.io/badge/License-Proprietary-blue.svg)](LICENSE)

---

## 🌟 Vision

**What The Game** is a next-generation gaming companion that leverages artificial intelligence to solve the modern gamer's paradox: *having hundreds of games but never knowing what to play*.

By integrating with multiple gaming platforms (Steam, GOG, Epic Games, and more) and utilizing advanced AI models, we provide:

- **Intelligent Recommendations**: AI-powered suggestions based on your play patterns, preferences, and mood
- **Unified Library Management**: One place to manage games across all your platforms
- **Smart Backlog Prioritization**: Let AI help you decide what to play based on your available time and preferences
- **Gaming Insights**: Understand your gaming habits with AI-analyzed statistics and trends
- **Social Discovery**: Find games your friends are playing and get group recommendations
- **Future Features**: Voice-based game search, AI gaming assistant, automated achievement tracking, and more

---

## 🚀 Core Features

### ✅ Current (Foundation)
- Multi-platform game library structure
- User and game management models
- Service architecture for platform integrations
- AI recommendation service framework
- RESTful API structure

### 🔨 In Development (Phase 1)
- **Platform Integrations**
  - Steam API integration (library sync, playtime, achievements)
  - GOG Galaxy API integration
  - Epic Games Store API integration
  
- **AI-Powered Recommendations**
  - Integration with OpenAI GPT-4 or Anthropic Claude
  - Personalized game suggestions based on:
    - Play history and patterns
    - Genre preferences
    - Time constraints
    - Current mood/preferences
    - Similar users' behaviors
  
- **Backlog Management**
  - Smart prioritization using AI
  - Completion tracking
  - Time-to-beat estimates
  - Priority queues

### 🎯 Planned (Phase 2+)
- **Advanced AI Features**
  - Natural language queries ("Find me a short, story-driven game")
  - AI gaming assistant (conversational interface)
  - Automated game categorization and tagging
  - Predictive playtime estimates
  - Mood-based recommendations
  
- **Social Features**
  - Friend libraries and recommendations
  - Group game suggestions for multiplayer
  - Community-driven insights
  - Game clubs and challenges
  
- **Analytics & Insights**
  - Gaming habit analysis
  - Cost-per-hour played
  - Genre distribution
  - Completion rate trends
  - Peak gaming times
  
- **Extended Platform Support**
  - Xbox Game Pass
  - PlayStation Network
  - Nintendo eShop
  - Itch.io
  - Humble Bundle
  - Amazon Games
  
- **Smart Features**
  - Price tracking and alerts
  - Sale notifications for wishlisted games
  - Automatic game updates tracking
  - Achievement progress tracking
  - Streaming integration (Twitch, YouTube)

---

## 🏗️ Architecture

### Technology Stack

**Backend**
- **Framework**: Ruby on Rails 8.1.2
- **Language**: Ruby 3.2.3
- **Database**: PostgreSQL 13+
- **Cache**: Solid Cache (Rails 8)
- **Background Jobs**: Solid Queue (Rails 8)
- **WebSockets**: Solid Cable (Rails 8)

**AI & ML**
- **Primary AI**: OpenAI GPT-4 / Anthropic Claude
- **Use Cases**: 
  - Natural language processing
  - Recommendation generation
  - User preference analysis
  - Content summarization
  - Conversational interface

**External APIs**
- Steam Web API
- GOG Galaxy API
- Epic Games Store API
- IGDB (Internet Game Database)
- RAWG Video Games Database
- HowLongToBeat API

**Infrastructure**
- **Deployment**: Docker + Kamal
- **CI/CD**: GitHub Actions
- **Monitoring**: (Planned) Sentry, New Relic
- **Caching**: Redis (Planned)
- **Search**: (Planned) Elasticsearch or PostgreSQL Full-Text

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        User Interface                        │
│  (Web App - Hotwire/Turbo, Mobile-Responsive, PWA Support)  │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│                   Rails Application Layer                    │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Controllers  │  │   Services   │  │   Models     │      │
│  │              │  │              │  │              │      │
│  │ • Games      │  │ • AI Svcs    │  │ • User       │      │
│  │ • Users      │  │ • Platforms  │  │ • Game       │      │
│  │ • Backlog    │  │ • Analytics  │  │ • UserGame   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└──────────┬────────────────┬────────────────┬────────────────┘
           │                │                │
┌──────────▼────────┐ ┌────▼──────────┐ ┌──▼─────────────────┐
│   PostgreSQL DB   │ │  Background   │ │   Cache Layer      │
│                   │ │     Jobs      │ │  (Solid Cache)     │
│ • Users           │ │               │ │                    │
│ • Games           │ │ • API Syncs   │ │ • API Responses    │
│ • UserGames       │ │ • AI Tasks    │ │ • Game Data        │
│ • Recommendations │ │ • Analytics   │ │ • User Sessions    │
└───────────────────┘ └───────────────┘ └────────────────────┘
           
           ┌──────────────────────────────────┐
           │    External Services             │
           ├──────────────────────────────────┤
           │ • Steam API                      │
           │ • GOG API                        │
           │ • Epic Games API                 │
           │ • OpenAI / Anthropic             │
           │ • IGDB / RAWG                    │
           │ • HowLongToBeat                  │
           └──────────────────────────────────┘
```

### Data Flow: AI Recommendations

```
1. User Request
   ↓
2. Gather User Context
   - Gaming history (playtime, genres, completion rates)
   - Current backlog (status, priority, time estimates)
   - Preferences (explicit and implicit)
   ↓
3. Build AI Prompt
   - User profile summary
   - Recent gaming patterns
   - Constraints (time available, mood, etc.)
   ↓
4. Query AI Service (OpenAI/Claude)
   - Stream response for real-time feedback
   - Parse structured recommendation data
   ↓
5. Post-Processing
   - Validate recommendations
   - Enhance with metadata from IGDB/RAWG
   - Calculate match scores
   ↓
6. Store & Return Results
   - Cache recommendations
   - Log for analysis
   - Return to user
```

---

## 📋 Quick Start

### Prerequisites
- Ruby 3.2.3
- PostgreSQL 13+
- Rails 8.1.2

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/what-the-game.git
cd what-the-game

# Install dependencies
bundle install

# Setup database
rails db:create db:migrate

# Configure environment variables
cp .env.example .env
# Edit .env with your API keys

# Start the server
rails server
```

Visit `http://localhost:3000`

### Running Tests

```bash
rails test                    # Run all tests
bin/rubocop                  # Check code style
bin/brakeman                 # Security scan
bin/bundler-audit            # Dependency vulnerabilities
```

---

## 🔧 Configuration

### Required API Keys

1. **Steam API Key**
   - Get it from: https://steamcommunity.com/dev/apikey
   - Used for: Library sync, game details, playtime

2. **AI Service** (Choose one or both)
   - **OpenAI**: https://platform.openai.com/api-keys
   - **Anthropic**: https://console.anthropic.com/
   - Used for: Recommendations, natural language queries, insights

3. **Optional Services**
   - **GOG**: https://devportal.gog.com/
   - **Epic Games**: https://dev.epicgames.com/
   - **IGDB**: https://www.igdb.com/api
   - **RAWG**: https://rawg.io/apidocs

See `.env.example` for complete configuration options.

---

## 📚 Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Detailed system architecture and design decisions
- **[ROADMAP.md](ROADMAP.md)** - Development roadmap and feature timeline
- **[AI_FEATURES.md](AI_FEATURES.md)** - AI capabilities and implementation details
- **[API.md](API.md)** - API endpoints and usage
- **[DEVELOPMENT.md](DEVELOPMENT.md)** - Development setup and guidelines

---

## 🤝 Contributing

This project is currently in active development. Contribution guidelines will be established as the project matures.

---

## 📄 License

Copyright © 2026. All rights reserved.

---

## 🎮 Why "What The Game"?

We've all been there - staring at a library of hundreds of games, asking ourselves *"What the game should I play?"* This platform answers that question intelligently, considering your preferences, available time, and gaming mood. No more decision paralysis, just good gaming recommendations.

---

## 🔮 Future Vision

Our long-term vision includes:
- **AI Gaming Companion**: A conversational AI that knows your gaming preferences better than you do
- **Cross-Platform Achievement Tracking**: Unified achievement system across all platforms
- **Smart Game Discovery**: Find hidden gems based on deep preference analysis
- **Gaming Time Optimization**: AI-suggested gaming schedules based on your calendar
- **Voice Interface**: "Hey Game, what should I play tonight?"
- **AR/VR Integration**: Virtual game library visualization
- **Blockchain Integration**: NFT-based game ownership tracking (if/when viable)

---

**Built with ❤️ by gamers, for gamers**
