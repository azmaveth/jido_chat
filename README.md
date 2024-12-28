# JidoChat

JidoChat is a structured chat channel system for Elixir that supports both human and AI agent participants, with customizable turn-taking strategies and flexible persistence options. It's designed for building scalable, real-time chat applications that can seamlessly integrate AI agents alongside human participants.

> ***BETA***: This is a beta release and the API is subject to change.

## Features

- **Flexible Chat Channels**: Create and manage multiple chat channels with customizable settings
- **Turn-Taking Strategies**: Built-in support for free-form and round-robin conversation patterns
- **Multi-Participant Support**: Handle both human users and AI agents in the same channel
- **Persistence Options**: Extensible persistence adapters, currently supports ETS and an in-memory adapter
- **LLM Integration Ready**: Built-in conversation context formatting for popular LLM APIs
- **Extensible Design**: Custom behaviors for turn-taking strategies and persistence

## Installation

Add `jido_chat` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:jido_chat, "~> 0.1.0"}
  ]
end
```

## Usage

### Basic Setup

```elixir
# Start a new chat channel
{:ok, channel_pid} = JidoChat.create_channel("channel-123")

# Add participants
human = %JidoChat.Participant{
  id: "user1",
  name: "Alice",
  type: :human
}

agent = %JidoChat.Participant{
  id: "bot1",
  name: "Helper Bot",
  type: :agent
}

:ok = JidoChat.join_channel(channel_pid, human)
:ok = JidoChat.join_channel(channel_pid, agent)

# Post messages
{:ok, message} = JidoChat.post_message(channel_pid, "user1", "Hello, bot!")
```

### Using Turn-Taking Strategies

```elixir
# Create a channel with round-robin strategy
{:ok, channel_pid} = JidoChat.create_channel("channel-456",
  strategy: JidoChat.Channel.Strategy.RoundRobin
)
```

### Getting Conversation Context for LLMs

```elixir
# Get recent messages formatted for ChatML
{:ok, conversation} = JidoChat.get_conversation_context(channel_pid,
  message_limit: 10,
  format: :chat_ml
)
```

## Configuration

Add to your `config.exs`:

```elixir
config :jido_chat,
  persistence: JidoChat.Channel.Persistence.ETS,
  default_message_limit: 1000,
  default_strategy: JidoChat.Channel.Strategy.FreeForm
```

## TODO

### Core Improvements
- [ ] Implement proper supervision tree
- [ ] Add dynamic supervision for channels
- [ ] Implement graceful process restart handling
- [ ] Add Phoenix PubSub integration
- [ ] Support message attachments

### Features
- [ ] Implement channel discovery
- [ ] Add message threading
- [ ] Support message reactions
- [ ] Add presence tracking
- [ ] Implement channel archiving
- [ ] Add support for message attachments
- [ ] Implement channel moderation features

### Chat Plugins
- [ ] Extend JidoChat to support Telegram
- [ ] Extend JidoChat to support Discord
- [ ] Extend JidoChat to support Slack

### Performance
- [ ] Add message batching
- [ ] Implement efficient pagination
- [ ] Add Nebulex Caching layer
- [ ] Implement presence tracking
- [ ] Optimize message storage and retrieval

### Monitoring & Observability
- [ ] Add Telemetry events
- [ ] Create health checks

### Security & Validation
- [ ] Add message content validation
- [ ] Implement rate limiting
- [ ] Add participant authentication
- [ ] Add input sanitization
- [ ] Implement channel authorization rules

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.