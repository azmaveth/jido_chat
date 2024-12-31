# JidoChat

[![Hex.pm](https://img.shields.io/hexpm/v/jido_chat.svg)](https://hex.pm/packages/jido_chat)
[![Hex Docs](https://img.shields.io/badge/hex-docs-green.svg)](https://hexdocs.pm/jido_chat)
[![Mix Test](https://github.com/agentjido/jido_chat/actions/workflows/elixir-ci.yml/badge.svg)](https://github.com/agentjido/jido_chat/actions/workflows/elixir-ci.yml)
[![Coverage Status](https://coveralls.io/repos/github/agentjido/jido_chat/badge.svg?branch=main)](https://coveralls.io/github/agentjido/jido_chat?branch=main)
[![Apache 2 License](https://img.shields.io/hexpm/l/jido_chat)](https://opensource.org/licenses/Apache-2.0)

JidoChat is a structured chat channel system for Elixir that supports both human and AI agent participants, with customizable turn-taking strategies and flexible persistence options. Built on OTP principles, it provides a robust foundation for real-time chat applications that seamlessly integrate AI agents alongside human participants.

> **NOTE**: This package is aimed at facilitating small-scale chat scenarios between humans and AI agents. It is not designed for large-scale chat applications. 

> **BETA**: JidoChat is currently in beta. The API may change in future versions.

## Key Features

- **Flexible Chat Channels**: Create and manage isolated chat rooms with customizable settings
- **Smart Turn Management**: Built-in support for various conversation patterns:
  - Free-form discussions
  - Round-robin turn taking
  - Custom turn-taking strategies
- **Multi-Participant Support**: 
  - Human and AI agent participants in the same channel
  - Role-based message handling
  - Extensible participant metadata
- **Persistence Options**: 
  - ETS-based storage (default)
  - In-memory storage for testing
  - Extensible persistence adapter system
- **LLM Integration**: 
  - Built-in conversation context formatting
  - Support for major LLM APIs (ChatML, Anthropic)
  - Customizable message formatting
- **Real-time Communication**:
  - PubSub-based message delivery
  - Event-driven architecture
  - Topic-based subscriptions

## Installation

Add `jido_chat` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:jido_chat, "~> 0.1.0"}
  ]
end
```

## Quick Start

### Creating a Channel

```elixir
# Start a new chat channel
{:ok, channel} = JidoChat.create_channel("my-channel")

# Or with custom settings
{:ok, channel} = JidoChat.create_channel("ai-channel",
  strategy: JidoChat.Channel.Strategy.RoundRobin,
  message_limit: 100
)
```

### Managing Participants

```elixir
# Add a human participant
human = %JidoChat.Participant{
  id: "user123",
  name: "Alice",
  type: :human,
  metadata: %{avatar_url: "https://example.com/avatar.jpg"}
}
:ok = JidoChat.join_channel(channel, human)

# Add an AI agent
agent = %JidoChat.Participant{
  id: "bot456",
  name: "Helper Bot",
  type: :agent,
  metadata: %{capabilities: [:chat]}
}
:ok = JidoChat.join_channel(channel, agent)
```

### Sending Messages

```elixir
# Post a message
{:ok, msg} = JidoChat.post_message(channel, "user123", "Hello, bot!")

# Handle the response
case JidoChat.post_message(channel, "bot456", "Hello! How can I help?") do
  {:ok, message} -> 
    # Message sent successfully
    process_message(message)
  {:error, reason} -> 
    # Handle error
    Logger.error("Failed to send message: #{inspect(reason)}")
end
```

### Getting Conversation Context

```elixir
# Get recent messages in ChatML format
{:ok, context} = JidoChat.get_conversation_context(channel,
  limit: 10,
  format: :chat_ml
)

# Format for Anthropic with system prompt
{:ok, context} = JidoChat.get_conversation_context(channel,
  system_prompt: "You are a helpful assistant",
  format: :anthropic
)
```

## Configuration

Configure JidoChat in your `config.exs`:

```elixir
config :jido_chat,
  persistence: JidoChat.Channel.Persistence.ETS,
  default_message_limit: 1000,
  default_strategy: JidoChat.Channel.Strategy.FreeForm
```

## Development Ideas

### Core Improvements
- [ ] Production-ready supervision tree
- [ ] Dynamic channel supervision
- [ ] Process restart handling
- [ ] Message attachment support

### Features
- [ ] Channel discovery and management
- [ ] Message threading support
- [ ] Reaction system
- [ ] Presence tracking
- [ ] Channel archiving
- [ ] Moderation tools

### Platform Integration
- [ ] Telegram adapter
- [ ] Discord adapter
- [ ] Slack adapter

### Performance
- [ ] Message batching
- [ ] Efficient pagination
- [ ] Caching layer (Nebulex)
- [ ] Storage optimizations

### Observability
- [ ] Telemetry integration
- [ ] Health check system
- [ ] Monitoring dashboards

### Security
- [ ] Content validation
- [ ] Rate limiting
- [ ] Authentication system
- [ ] Authorization rules
- [ ] Input sanitization

## Documentation

- [Getting Started Guide](guides/getting_started.md)
- [API Reference](https://hexdocs.pm/jido_chat)
- [Architecture Overview](guides/architecture.md)
- [Contributing Guide](CONTRIBUTING.md)

## Contributing

We welcome contributions! Please feel free to submit a PR.

## License

This project is licensed under the Apache-2.0 License - see the [LICENSE.md](LICENSE.md) file for details.

## Acknowledgments

Special thanks to:
- The Elixir community
- Contributors and early adopters
- Our open source dependencies