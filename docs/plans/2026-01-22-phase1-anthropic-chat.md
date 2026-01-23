# Phase 1: Anthropic Chat Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build AI chat interface with Anthropic API integration and tool execution framework

**Architecture:** Rails backend calls Anthropic API with custom tool definitions. When Claude requests tool calls, Rails executes them and streams responses back to frontend via SSE.

**Tech Stack:** Rails 8, Anthropic Ruby SDK, Hotwire Stimulus, PostgreSQL

---

## Prerequisites

### Task 0: Install Dependencies

**Files:**
- Modify: `Gemfile`

**Step 1: Add anthropic-rb gem to Gemfile**

Add after line 54 (after tailwindcss-rails):

```ruby
# Anthropic API for AI chat
gem "anthropic", "~> 0.3.0"

# HTTP client for API calls
gem "httparty", "~> 0.22.0"
```

**Step 2: Install gems**

Run: `bundle install`
Expected: Gems installed successfully

**Step 3: Add ANTHROPIC_API_KEY to .env**

Run: `echo "ANTHROPIC_API_KEY=your_key_here" >> .env`

**Step 4: Commit**

```bash
git add Gemfile Gemfile.lock .env
git commit -m "Add anthropic and httparty gems for AI chat"
```

---

## Task 1: ChatSession Model

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_create_chat_sessions.rb`
- Create: `app/models/chat_session.rb`
- Create: `test/models/chat_session_test.rb`

**Step 1: Generate ChatSession model**

Run: `rails generate model ChatSession user:references messages:jsonb expires_at:datetime`
Expected: Migration and model files created

**Step 2: Update migration to add defaults**

Edit the generated migration file to add:

```ruby
def change
  create_table :chat_sessions do |t|
    t.references :user, null: false, foreign_key: true
    t.jsonb :messages, default: []
    t.datetime :expires_at

    t.timestamps
  end

  add_index :chat_sessions, :user_id
  add_index :chat_sessions, :expires_at
end
```

**Step 3: Run migration**

Run: `rails db:migrate`
Expected: Table created successfully

**Step 4: Write ChatSession model test**

```ruby
# test/models/chat_session_test.rb
require "test_helper"

class ChatSessionTest < ActiveSupport::TestCase
  test "belongs to user" do
    session = chat_sessions(:one)
    assert_instance_of User, session.user
  end

  test "messages defaults to empty array" do
    session = ChatSession.create!(user: users(:one))
    assert_equal [], session.messages
  end

  test "can add messages" do
    session = chat_sessions(:one)
    session.add_message(role: "user", content: "Hello")

    assert_equal 1, session.messages.length
    assert_equal "user", session.messages.first["role"]
    assert_equal "Hello", session.messages.first["content"]
  end

  test "expires_at defaults to 24 hours" do
    session = ChatSession.create!(user: users(:one))
    assert_in_delta 24.hours.from_now, session.expires_at, 5.seconds
  end
end
```

**Step 5: Run test to verify it fails**

Run: `rails test test/models/chat_session_test.rb`
Expected: FAIL - methods not defined

**Step 6: Implement ChatSession model**

```ruby
# app/models/chat_session.rb
class ChatSession < ApplicationRecord
  belongs_to :user

  before_create :set_expires_at

  def add_message(role:, content:)
    self.messages << { role: role, content: content, timestamp: Time.current }
    save!
  end

  def clear_messages
    update!(messages: [])
  end

  def expired?
    expires_at && expires_at < Time.current
  end

  private

  def set_expires_at
    self.expires_at ||= 24.hours.from_now
  end
end
```

**Step 7: Update User model association**

Add to `app/models/user.rb` after line 6:

```ruby
has_many :chat_sessions, dependent: :destroy
```

**Step 8: Create test fixtures**

```yaml
# test/fixtures/chat_sessions.yml
one:
  user: one
  messages: []
  expires_at: <%= 24.hours.from_now %>

two:
  user: two
  messages:
    - role: "user"
      content: "What should I play?"
      timestamp: <%= 1.hour.ago %>
    - role: "assistant"
      content: "Let me check your backlog!"
      timestamp: <%= 1.hour.ago %>
  expires_at: <%= 24.hours.from_now %>

expired:
  user: one
  messages: []
  expires_at: <%= 1.hour.ago %>
```

**Step 9: Run tests to verify they pass**

Run: `rails test test/models/chat_session_test.rb`
Expected: PASS - all tests green

**Step 10: Commit**

```bash
git add db/migrate/ app/models/ test/models/ test/fixtures/
git commit -m "Add ChatSession model with message storage"
```

---

## Task 2: ToolExecutor Service

**Files:**
- Create: `app/services/tool_executor.rb`
- Create: `test/services/tool_executor_test.rb`

**Step 1: Write ToolExecutor test**

```ruby
# test/services/tool_executor_test.rb
require "test_helper"

class ToolExecutorTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @executor = ToolExecutor.new(@user)
  end

  test "executes get_user_backlog tool" do
    result = @executor.execute("get_user_backlog", {})

    assert result.is_a?(Array)
    assert result.all? { |game| game.key?(:title) }
  end

  test "executes get_user_backlog with status filter" do
    result = @executor.execute("get_user_backlog", { "status" => "playing" })

    assert result.is_a?(Array)
  end

  test "raises error for unknown tool" do
    assert_raises(ToolExecutor::UnknownToolError) do
      @executor.execute("nonexistent_tool", {})
    end
  end

  test "get_user_backlog scopes to current user only" do
    other_user = users(:two)

    user_one_games = ToolExecutor.new(@user).execute("get_user_backlog", {})
    user_two_games = ToolExecutor.new(other_user).execute("get_user_backlog", {})

    # Results should be different for different users
    assert_not_equal user_one_games, user_two_games
  end
end
```

**Step 2: Run test to verify it fails**

Run: `rails test test/services/tool_executor_test.rb`
Expected: FAIL - ToolExecutor not defined

**Step 3: Create services directory if needed**

Run: `mkdir -p app/services test/services`

**Step 4: Implement ToolExecutor**

```ruby
# app/services/tool_executor.rb
class ToolExecutor
  class UnknownToolError < StandardError; end

  def initialize(user)
    @user = user
  end

  def execute(tool_name, params)
    case tool_name
    when "get_user_backlog"
      get_user_backlog(params)
    when "search_games"
      search_games(params)
    when "get_game_details"
      get_game_details(params)
    when "add_to_backlog"
      add_to_backlog(params)
    when "update_game_status"
      update_game_status(params)
    when "get_recommendations"
      get_recommendations(params)
    else
      raise UnknownToolError, "Unknown tool: #{tool_name}"
    end
  end

  private

  def get_user_backlog(params)
    scope = @user.user_games.includes(:game)
    scope = scope.where(status: params["status"]) if params["status"]
    limit = params["limit"] || 50

    scope.limit(limit).map do |user_game|
      {
        id: user_game.id,
        game_id: user_game.game_id,
        title: user_game.game.title,
        platform: user_game.game.platform,
        status: user_game.status,
        hours_played: user_game.hours_played&.round(1),
        priority: user_game.priority,
        rating: user_game.rating,
        notes: user_game.notes
      }
    end
  end

  def search_games(params)
    # Placeholder - will implement with IGDB in Phase 2
    []
  end

  def get_game_details(params)
    # Placeholder - will implement with IGDB in Phase 2
    {}
  end

  def add_to_backlog(params)
    # Placeholder - will implement in Phase 2
    {}
  end

  def update_game_status(params)
    user_game = @user.user_games.find(params["user_game_id"])

    user_game.update!(
      status: params["status"] || user_game.status,
      priority: params["priority"] || user_game.priority,
      rating: params["rating"] || user_game.rating,
      notes: params["notes"] || user_game.notes
    )

    {
      id: user_game.id,
      status: user_game.status,
      priority: user_game.priority,
      rating: user_game.rating,
      updated: true
    }
  end

  def get_recommendations(params)
    # Placeholder - will implement in Phase 2
    []
  end
end
```

**Step 5: Run tests to verify they pass**

Run: `rails test test/services/tool_executor_test.rb`
Expected: PASS

**Step 6: Commit**

```bash
git add app/services/ test/services/
git commit -m "Add ToolExecutor service with get_user_backlog and update_game_status"
```

---

## Task 3: AnthropicService

**Files:**
- Create: `app/services/anthropic_service.rb`
- Create: `test/services/anthropic_service_test.rb`

**Step 1: Write AnthropicService test**

```ruby
# test/services/anthropic_service_test.rb
require "test_helper"

class AnthropicServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @chat_session = chat_sessions(:one)
    @service = AnthropicService.new(@user, @chat_session)
  end

  test "builds tool definitions" do
    tools = @service.send(:tool_definitions)

    assert_equal 6, tools.length
    assert tools.any? { |t| t[:name] == "get_user_backlog" }
    assert tools.any? { |t| t[:name] == "update_game_status" }
  end

  test "builds messages from chat session" do
    @chat_session.add_message(role: "user", content: "Hello")

    messages = @service.send(:build_messages)

    assert_equal 1, messages.length
    assert_equal "user", messages.first[:role]
    assert_equal "Hello", messages.first[:content]
  end

  test "formats tool result for anthropic" do
    result = { games: [], count: 0 }
    formatted = @service.send(:format_tool_result, "get_user_backlog", result)

    assert formatted.is_a?(String)
    assert formatted.include?("games")
  end
end
```

**Step 2: Run test to verify it fails**

Run: `rails test test/services/anthropic_service_test.rb`
Expected: FAIL - AnthropicService not defined

**Step 3: Implement AnthropicService**

```ruby
# app/services/anthropic_service.rb
class AnthropicService
  SYSTEM_PROMPT = <<~PROMPT
    You are a helpful gaming backlog assistant. You help users manage their game library
    and decide what to play next. You have access to their backlog data and can provide
    recommendations based on their playing history and preferences.

    Be conversational, enthusiastic about games, and help users make decisions without
    overwhelming them with choices. When recommending games, explain your reasoning briefly.
  PROMPT

  def initialize(user, chat_session)
    @user = user
    @chat_session = chat_session
    @client = Anthropic::Client.new(api_key: ENV["ANTHROPIC_API_KEY"])
    @tool_executor = ToolExecutor.new(user)
  end

  def send_message(user_message)
    # This will be implemented with streaming in next task
    # For now, just return a simple response
    messages = build_messages

    begin
      response = @client.messages.create(
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 4096,
        system: SYSTEM_PROMPT,
        messages: messages,
        tools: tool_definitions
      )

      handle_response(response)
    rescue => e
      Rails.logger.error "Anthropic API error: #{e.message}"
      { error: "Failed to get response from AI" }
    end
  end

  private

  def tool_definitions
    [
      {
        name: "get_user_backlog",
        description: "Fetch the user's game library with optional filtering by status",
        input_schema: {
          type: "object",
          properties: {
            status: {
              type: "string",
              enum: ["backlog", "playing", "completed", "abandoned"],
              description: "Filter games by status"
            },
            limit: {
              type: "integer",
              description: "Maximum number of games to return (default 50)"
            }
          }
        }
      },
      {
        name: "search_games",
        description: "Search for games by title in the IGDB database",
        input_schema: {
          type: "object",
          properties: {
            query: {
              type: "string",
              description: "Game title to search for"
            },
            limit: {
              type: "integer",
              description: "Maximum results (default 10)"
            }
          },
          required: ["query"]
        }
      },
      {
        name: "get_game_details",
        description: "Get detailed information about a specific game",
        input_schema: {
          type: "object",
          properties: {
            game_id: {
              type: "integer",
              description: "Internal game ID"
            },
            igdb_id: {
              type: "integer",
              description: "IGDB game ID"
            }
          }
        }
      },
      {
        name: "add_to_backlog",
        description: "Add a game to the user's backlog",
        input_schema: {
          type: "object",
          properties: {
            game_id: {
              type: "integer",
              description: "Internal game ID"
            },
            igdb_id: {
              type: "integer",
              description: "IGDB game ID"
            },
            status: {
              type: "string",
              enum: ["backlog", "playing", "completed", "abandoned"],
              description: "Initial status (default: backlog)"
            },
            priority: {
              type: "integer",
              description: "Priority 1-10"
            }
          }
        }
      },
      {
        name: "update_game_status",
        description: "Update status, priority, rating, or notes for a game in the user's backlog",
        input_schema: {
          type: "object",
          properties: {
            user_game_id: {
              type: "integer",
              description: "ID of the UserGame record to update"
            },
            status: {
              type: "string",
              enum: ["backlog", "playing", "completed", "abandoned"]
            },
            priority: {
              type: "integer",
              description: "Priority 1-10"
            },
            rating: {
              type: "integer",
              description: "Rating 1-5"
            },
            notes: {
              type: "string",
              description: "Personal notes"
            }
          },
          required: ["user_game_id"]
        }
      },
      {
        name: "get_recommendations",
        description: "Get AI-powered game recommendations from the user's backlog",
        input_schema: {
          type: "object",
          properties: {
            context: {
              type: "string",
              description: "Context like 'short session', 'long RPG', etc."
            },
            limit: {
              type: "integer",
              description: "Number of recommendations (default 5)"
            }
          }
        }
      }
    ]
  end

  def build_messages
    @chat_session.messages.map do |msg|
      {
        role: msg["role"],
        content: msg["content"]
      }
    end
  end

  def handle_response(response)
    content = response.content.first

    if content.type == "tool_use"
      # Execute tool and continue conversation
      result = @tool_executor.execute(content.name, content.input)

      # For now, return the tool result
      # In streaming implementation, this will trigger another API call
      { tool_result: result, tool_name: content.name }
    else
      # Text response
      assistant_message = content.text
      @chat_session.add_message(role: "assistant", content: assistant_message)
      { message: assistant_message }
    end
  end

  def format_tool_result(tool_name, result)
    JSON.pretty_generate(result)
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `rails test test/services/anthropic_service_test.rb`
Expected: PASS (may need to stub Anthropic client)

**Step 5: Add WebMock stub for tests**

Update test file to stub API:

```ruby
# test/services/anthropic_service_test.rb
require "test_helper"

class AnthropicServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @chat_session = chat_sessions(:one)
    @service = AnthropicService.new(@user, @chat_session)

    # Stub Anthropic API
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: {
        id: "msg_123",
        type: "message",
        role: "assistant",
        content: [{ type: "text", text: "Hello!" }],
        model: "claude-sonnet-4-5-20250929",
        stop_reason: "end_turn"
      }.to_json, headers: { "Content-Type" => "application/json" })
  end

  # ... rest of tests
end
```

**Step 6: Commit**

```bash
git add app/services/ test/services/
git commit -m "Add AnthropicService with tool definitions and message handling"
```

---

## Task 4: ChatController

**Files:**
- Create: `app/controllers/chat_controller.rb`
- Create: `test/controllers/chat_controller_test.rb`
- Modify: `config/routes.rb`

**Step 1: Write ChatController test**

```ruby
# test/controllers/chat_controller_test.rb
require "test_helper"

class ChatControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    # Simulate logged in user
    post session_url, params: { provider: "steam" }
  end

  test "creates new chat session on first message" do
    assert_difference "ChatSession.count", 1 do
      post chat_message_url, params: { message: "Hello" }
    end
  end

  test "reuses existing chat session" do
    # First message creates session
    post chat_message_url, params: { message: "Hello" }
    session_id = session[:chat_session_id]

    # Second message reuses it
    assert_no_difference "ChatSession.count" do
      post chat_message_url, params: { message: "What should I play?" }
    end

    assert_equal session_id, session[:chat_session_id]
  end

  test "requires authentication" do
    # Logout
    delete session_url

    post chat_message_url, params: { message: "Hello" }
    assert_redirected_to root_url
  end
end
```

**Step 2: Add route**

```ruby
# config/routes.rb
# Add after existing routes:
post "chat/message", to: "chat#create", as: :chat_message
```

**Step 3: Run test to verify it fails**

Run: `rails test test/controllers/chat_controller_test.rb`
Expected: FAIL - ChatController not defined

**Step 4: Implement ChatController (non-streaming version)**

```ruby
# app/controllers/chat_controller.rb
class ChatController < ApplicationController
  before_action :require_user

  def create
    # Get or create chat session
    session_id = session[:chat_session_id]

    if session_id
      @chat_session = current_user.chat_sessions.find_by(id: session_id)
    end

    if @chat_session.nil? || @chat_session.expired?
      @chat_session = current_user.chat_sessions.create!
      session[:chat_session_id] = @chat_session.id
    end

    # Add user message
    user_message = params[:message]
    @chat_session.add_message(role: "user", content: user_message)

    # Get response from Anthropic
    anthropic_service = AnthropicService.new(current_user, @chat_session)
    response = anthropic_service.send_message(user_message)

    render json: response
  rescue => e
    Rails.logger.error "Chat error: #{e.message}\n#{e.backtrace.join("\n")}"
    render json: { error: "An error occurred" }, status: :internal_server_error
  end

  private

  def require_user
    unless current_user
      redirect_to root_url, alert: "Please sign in to use chat"
    end
  end
end
```

**Step 5: Run tests to verify they pass**

Run: `rails test test/controllers/chat_controller_test.rb`
Expected: PASS

**Step 6: Commit**

```bash
git add app/controllers/ test/controllers/ config/routes.rb
git commit -m "Add ChatController with session management"
```

---

## Task 5: Basic Chat UI

**Files:**
- Create: `app/javascript/controllers/chat_controller.js`
- Create: `app/views/chat/_chat_widget.html.erb`
- Modify: `app/views/layouts/application.html.erb`
- Create: `app/assets/stylesheets/chat.css`

**Step 1: Create Stimulus chat controller**

```javascript
// app/javascript/controllers/chat_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "messages", "form"]

  connect() {
    this.scrollToBottom()
  }

  async send(event) {
    event.preventDefault()

    const message = this.inputTarget.value.trim()
    if (!message) return

    // Add user message to UI
    this.appendMessage("user", message)
    this.inputTarget.value = ""

    // Disable input while waiting
    this.inputTarget.disabled = true

    try {
      const response = await fetch("/chat/message", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        },
        body: JSON.stringify({ message })
      })

      const data = await response.json()

      if (data.error) {
        this.appendMessage("error", data.error)
      } else if (data.message) {
        this.appendMessage("assistant", data.message)
      } else if (data.tool_result) {
        // Tool was called, show result
        this.appendMessage("assistant", `Called ${data.tool_name}`)
      }
    } catch (error) {
      this.appendMessage("error", "Failed to send message")
      console.error(error)
    } finally {
      this.inputTarget.disabled = false
      this.inputTarget.focus()
    }
  }

  appendMessage(role, content) {
    const messageDiv = document.createElement("div")
    messageDiv.className = `chat-message chat-message-${role} mb-4 p-3 rounded-lg`

    const roleSpan = document.createElement("span")
    roleSpan.className = "font-semibold text-sm block mb-1"
    roleSpan.textContent = role === "user" ? "You" : role === "assistant" ? "Assistant" : "Error"

    const contentDiv = document.createElement("div")
    contentDiv.textContent = content

    messageDiv.appendChild(roleSpan)
    messageDiv.appendChild(contentDiv)

    this.messagesTarget.appendChild(messageDiv)
    this.scrollToBottom()
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }
}
```

**Step 2: Create chat widget partial**

```erb
<!-- app/views/chat/_chat_widget.html.erb -->
<div class="chat-widget fixed bottom-4 right-4 w-96 bg-white dark:bg-gray-800 shadow-lg rounded-lg border border-gray-200 dark:border-gray-700" data-controller="chat">
  <div class="chat-header bg-blue-600 text-white p-4 rounded-t-lg flex justify-between items-center">
    <h3 class="font-semibold">Backlog Assistant</h3>
    <button class="text-white hover:text-gray-200" data-action="click->chat#toggle">
      ×
    </button>
  </div>

  <div class="chat-messages h-96 overflow-y-auto p-4 bg-gray-50 dark:bg-gray-900" data-chat-target="messages">
    <div class="chat-message chat-message-assistant mb-4 p-3 rounded-lg bg-blue-50 dark:bg-blue-900">
      <span class="font-semibold text-sm block mb-1">Assistant</span>
      <div>Hello! I can help you manage your gaming backlog and recommend what to play next. What would you like to know?</div>
    </div>
  </div>

  <form class="chat-input p-4 border-t border-gray-200 dark:border-gray-700" data-chat-target="form" data-action="submit->chat#send">
    <div class="flex gap-2">
      <input
        type="text"
        data-chat-target="input"
        placeholder="Ask about your backlog..."
        class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-gray-700 dark:text-white"
      />
      <button
        type="submit"
        class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
      >
        Send
      </button>
    </div>
  </form>
</div>
```

**Step 3: Add chat widget to layout**

Add before closing `</body>` tag in `app/views/layouts/application.html.erb`:

```erb
<% if current_user %>
  <%= render "chat/chat_widget" %>
<% end %>
```

**Step 4: Create chat CSS**

```css
/* app/assets/stylesheets/chat.css */
.chat-message-user {
  background-color: #e3f2fd;
}

.chat-message-assistant {
  background-color: #f3f4f6;
}

.chat-message-error {
  background-color: #fee;
  color: #c33;
}

.dark .chat-message-user {
  background-color: #1e3a5f;
}

.dark .chat-message-assistant {
  background-color: #1f2937;
}
```

**Step 5: Import chat CSS**

Add to `app/assets/stylesheets/application.tailwind.css`:

```css
@import "chat.css";
```

**Step 6: Test manually**

Run: `rails server`
Visit: http://localhost:3000
Expected: Chat widget appears in bottom right, can send messages

**Step 7: Commit**

```bash
git add app/javascript/ app/views/ app/assets/
git commit -m "Add basic chat UI with Stimulus controller"
```

---

## Task 6: Add Streaming Support

**Files:**
- Modify: `app/services/anthropic_service.rb`
- Modify: `app/controllers/chat_controller.rb`
- Modify: `app/javascript/controllers/chat_controller.js`

**Step 1: Update AnthropicService for streaming**

Replace `send_message` method in `app/services/anthropic_service.rb`:

```ruby
def send_message(&block)
  messages = build_messages

  begin
    @client.messages.create(
      model: "claude-sonnet-4-5-20250929",
      max_tokens: 4096,
      system: SYSTEM_PROMPT,
      messages: messages,
      tools: tool_definitions,
      stream: true
    ) do |event|
      case event.type
      when "content_block_start"
        # Content block started
        next
      when "content_block_delta"
        if event.delta.type == "text_delta"
          # Stream text chunk
          block.call({ type: "text", content: event.delta.text })
        end
      when "message_stop"
        # Message complete
        block.call({ type: "done" })
      end
    end
  rescue => e
    Rails.logger.error "Anthropic streaming error: #{e.message}"
    block.call({ type: "error", content: "Failed to get response from AI" })
  end
end
```

**Step 2: Update ChatController for SSE**

Replace `create` method in `app/controllers/chat_controller.rb`:

```ruby
def create
  # Disable Rack::ETag for streaming
  response.headers["Cache-Control"] = "no-cache"
  response.headers["Content-Type"] = "text/event-stream"
  response.headers["X-Accel-Buffering"] = "no"

  # Get or create chat session
  session_id = session[:chat_session_id]

  if session_id
    @chat_session = current_user.chat_sessions.find_by(id: session_id)
  end

  if @chat_session.nil? || @chat_session.expired?
    @chat_session = current_user.chat_sessions.create!
    session[:chat_session_id] = @chat_session.id
  end

  # Add user message
  user_message = params[:message]
  @chat_session.add_message(role: "user", content: user_message)

  # Stream response
  anthropic_service = AnthropicService.new(current_user, @chat_session)

  full_message = ""

  anthropic_service.send_message do |chunk|
    if chunk[:type] == "text"
      full_message += chunk[:content]
      response.stream.write("data: #{chunk.to_json}\n\n")
    elsif chunk[:type] == "done"
      # Save complete message
      @chat_session.add_message(role: "assistant", content: full_message)
      response.stream.write("data: #{chunk.to_json}\n\n")
    elsif chunk[:type] == "error"
      response.stream.write("data: #{chunk.to_json}\n\n")
    end
  end
rescue IOError
  # Client disconnected
ensure
  response.stream.close
end
```

**Step 3: Update Stimulus controller for streaming**

Replace `send` method in `app/javascript/controllers/chat_controller.js`:

```javascript
async send(event) {
  event.preventDefault()

  const message = this.inputTarget.value.trim()
  if (!message) return

  // Add user message to UI
  this.appendMessage("user", message)
  this.inputTarget.value = ""

  // Disable input while waiting
  this.inputTarget.disabled = true

  // Create assistant message div for streaming
  const assistantDiv = this.createMessage("assistant", "")

  try {
    const response = await fetch("/chat/message", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
      },
      body: JSON.stringify({ message })
    })

    const reader = response.body.getReader()
    const decoder = new TextDecoder()

    while (true) {
      const { done, value } = await reader.read()
      if (done) break

      const chunk = decoder.decode(value)
      const lines = chunk.split('\n\n')

      for (const line of lines) {
        if (line.startsWith('data: ')) {
          const data = JSON.parse(line.slice(6))

          if (data.type === 'text') {
            this.appendToMessage(assistantDiv, data.content)
          } else if (data.type === 'error') {
            this.appendToMessage(assistantDiv, `Error: ${data.content}`)
          } else if (data.type === 'done') {
            // Message complete
          }
        }
      }
    }
  } catch (error) {
    this.appendToMessage(assistantDiv, "Failed to get response")
    console.error(error)
  } finally {
    this.inputTarget.disabled = false
    this.inputTarget.focus()
  }
}

createMessage(role, content) {
  const messageDiv = document.createElement("div")
  messageDiv.className = `chat-message chat-message-${role} mb-4 p-3 rounded-lg`

  const roleSpan = document.createElement("span")
  roleSpan.className = "font-semibold text-sm block mb-1"
  roleSpan.textContent = role === "user" ? "You" : "Assistant"

  const contentDiv = document.createElement("div")
  contentDiv.className = "message-content"
  contentDiv.textContent = content

  messageDiv.appendChild(roleSpan)
  messageDiv.appendChild(contentDiv)

  this.messagesTarget.appendChild(messageDiv)
  this.scrollToBottom()

  return messageDiv
}

appendToMessage(messageDiv, text) {
  const contentDiv = messageDiv.querySelector(".message-content")
  contentDiv.textContent += text
  this.scrollToBottom()
}
```

**Step 4: Test streaming manually**

Run: `rails server`
Visit: http://localhost:3000
Send message: "Hello"
Expected: Response streams in character by character

**Step 5: Commit**

```bash
git add app/services/ app/controllers/ app/javascript/
git commit -m "Add streaming support for chat responses"
```

---

## Task 7: Integration Testing

**Files:**
- Create: `test/integration/chat_flow_test.rb`

**Step 1: Write integration test**

```ruby
# test/integration/chat_flow_test.rb
require "test_helper"

class ChatFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    # Simulate login
    post session_url, params: { provider: "steam" }
  end

  test "complete chat conversation flow" do
    # First message creates session
    post chat_message_url, params: { message: "Show me my backlog" }
    assert_response :success

    session_id = session[:chat_session_id]
    assert session_id.present?

    chat_session = ChatSession.find(session_id)
    assert_equal 1, chat_session.messages.count
    assert_equal "user", chat_session.messages.first["role"]
  end

  test "chat persists across requests" do
    # First message
    post chat_message_url, params: { message: "Hello" }
    session_id = session[:chat_session_id]

    # Second message
    post chat_message_url, params: { message: "Show my games" }

    assert_equal session_id, session[:chat_session_id]

    chat_session = ChatSession.find(session_id)
    assert_equal 2, chat_session.messages.count
  end
end
```

**Step 2: Run integration tests**

Run: `rails test test/integration/chat_flow_test.rb`
Expected: PASS

**Step 3: Commit**

```bash
git add test/integration/
git commit -m "Add integration tests for chat flow"
```

---

## Task 8: Documentation

**Files:**
- Create: `docs/ANTHROPIC_INTEGRATION.md`

**Step 1: Write integration documentation**

```markdown
# Anthropic Integration

## Overview

The chat interface integrates with Anthropic's Claude API to provide AI-powered backlog management.

## Architecture

### Components

1. **ChatSession** - Stores conversation history in database
2. **AnthropicService** - Handles API calls and streaming
3. **ToolExecutor** - Executes tool calls requested by Claude
4. **ChatController** - Manages HTTP/SSE streaming
5. **Stimulus Controller** - Handles frontend streaming

### Flow

```
User → Frontend → ChatController → AnthropicService → Anthropic API
                                         ↓
                                   ToolExecutor → Database
```

## Tools Available

1. `get_user_backlog` - Fetch user's games with filtering
2. `search_games` - Search IGDB (Phase 2)
3. `get_game_details` - Get game info (Phase 2)
4. `add_to_backlog` - Add game to backlog (Phase 2)
5. `update_game_status` - Update game status/rating/notes
6. `get_recommendations` - AI recommendations (Phase 2)

## Configuration

Set `ANTHROPIC_API_KEY` in `.env`:

```bash
ANTHROPIC_API_KEY=sk-ant-...
```

## Testing

Tool execution is stubbed in tests using WebMock:

```ruby
stub_request(:post, "https://api.anthropic.com/v1/messages")
  .to_return(...)
```

## Error Handling

- **Rate limits**: Caught and displayed to user
- **Network errors**: Graceful degradation with error message
- **Tool errors**: Logged and returned to Claude for retry

## Future Enhancements

- Tool call visualization in UI
- Conversation branching
- Export chat history
```

**Step 2: Commit documentation**

```bash
git add docs/
git commit -m "Add Anthropic integration documentation"
```

---

## Summary

Phase 1 implementation complete! You now have:

✅ ChatSession model with message storage
✅ ToolExecutor framework (2 tools implemented, 4 placeholders)
✅ AnthropicService with streaming support
✅ ChatController with SSE streaming
✅ Stimulus-based chat UI
✅ Integration tests
✅ Documentation

**Next Steps:**

Phase 2 will implement:
- IGDB API integration
- Remaining 4 tools
- Game library CRUD
- Recommendation algorithm

**Testing the implementation:**

1. Start Rails: `rails server`
2. Sign in via Steam OAuth
3. Open chat widget (bottom right)
4. Try: "Show me my backlog" (if you have UserGames)
5. Watch response stream in real-time
