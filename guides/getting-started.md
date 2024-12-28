# Getting Started with JidoChat

This guide will help you get started with JidoChat, a structured chat system supporting both human and AI participants with customizable turn-taking strategies and persistence.

## Table of Contents

- [Getting Started with JidoChat](#getting-started-with-jidochat)
  - [Table of Contents](#table-of-contents)
  - [Installation](#installation)
  - [Basic Usage](#basic-usage)
    - [Creating Channels](#creating-channels)
    - [Managing Participants](#managing-participants)
    - [Sending Messages](#sending-messages)
    - [Reading History](#reading-history)
  - [Turn-Taking Strategies](#turn-taking-strategies)
    - [Free-Form Chat](#free-form-chat)
    - [Round-Robin for AI Agents](#round-robin-for-ai-agents)
  - [Message Persistence](#message-persistence)
    - [ETS Storage (Default)](#ets-storage-default)
    - [In-Memory Storage (Testing)](#in-memory-storage-testing)
  - [Advanced Features](#advanced-features)
    - [Message Metadata](#message-metadata)
    - [Event Subscriptions](#event-subscriptions)
  - [Error Handling](#error-handling)

## Installation

Add JidoChat to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:jido_chat, "~> 0.1.0"}
  ]
end
```

After adding JidoChat to your dependencies, run:

```bash
$ mix deps.get
```

## Basic Usage

### Creating Channels

Create your first chat channel with default settings:

```elixir
# Basic channel with default settings
{:ok, channel} = JidoChat.create_channel("my-first-channel")

# Channel with custom configuration
{:ok, channel} = JidoChat.create_channel("custom-channel", 
  strategy: JidoChat.Channel.Strategy.RoundRobin,
  message_limit: 500
)
```

### Managing Participants

Add human and AI participants to your channels:

```elixir
# Create a human participant
human = %JidoChat.Participant{
  id: "user123",
  name: "Alice",
  type: :human,
  metadata: %{
    avatar_url: "https://example.com/avatar.png"
  }
}

# Add human to channel
:ok = JidoChat.join_channel(channel, human)

# Create an AI agent
agent = %JidoChat.Participant{
  id: "bot456",
  name: "Helper Bot",
  type: :agent,
  metadata: %{
    capabilities: [:chat]
  }
}

# Add agent to channel
:ok = JidoChat.join_channel(channel, agent)
```

### Sending Messages

Post messages to the channel:

```elixir
# Send a message from a human participant
{:ok, message} = JidoChat.post_message(channel, "user123", "Hello everyone!")

# Send a message from an AI agent
{:ok, agent_msg} = JidoChat.post_message(channel, "bot456", "Hello! How can I help?")
```

### Reading History

Retrieve conversation context in different formats:

```elixir
# Get recent messages in ChatML format
{:ok, context} = JidoChat.get_conversation_context(channel,
  limit: 10,
  format: :chat_ml
)

# Get conversation with system prompt
{:ok, context} = JidoChat.get_conversation_context(channel,
  system_prompt: "You are a helpful assistant",
  format: :anthropic
)
```

## Turn-Taking Strategies

JidoChat supports different turn-taking strategies to control conversation flow:

### Free-Form Chat

Allow all participants to speak at any time:

```elixir
{:ok, channel} = JidoChat.create_channel("free-chat",
  strategy: JidoChat.Channel.Strategy.FreeForm
)
```

### Round-Robin for AI Agents

Coordinate multiple AI agents in sequence:

```elixir
{:ok, channel} = JidoChat.create_channel("ai-coordination",
  strategy: JidoChat.Channel.Strategy.RoundRobin
)

# Add multiple AI agents
agents = [
  %JidoChat.Participant{
    id: "agent1",
    name: "Research Bot",
    type: :agent
  },
  %JidoChat.Participant{
    id: "agent2", 
    name: "Writing Bot",
    type: :agent
  },
  %JidoChat.Participant{
    id: "agent3",
    name: "Review Bot",
    type: :agent
  }
]

Enum.each(agents, &JidoChat.join_channel(channel, &1))
```

## Message Persistence

JidoChat offers multiple persistence options:

### ETS Storage (Default)

```elixir
{:ok, channel} = JidoChat.create_channel("persistent-chat",
  persistence: JidoChat.Channel.Persistence.ETS
)
```

### In-Memory Storage (Testing)

```elixir
{:ok, channel} = JidoChat.create_channel("test-chat",
  persistence: JidoChat.Channel.Persistence.Memory
)
```

## Advanced Features

### Message Metadata

Create messages with rich metadata:

```elixir
# Create a message with attachment metadata
{:ok, msg} = JidoChat.Message.create("Hello with attachment!", "user123",
  type: :attachment,
  metadata: %{
    file_url: "https://example.com/file.pdf",
    file_type: "application/pdf",
    file_size: 1024
  }
)

# Post the message
{:ok, _} = JidoChat.post_message(channel, msg.participant_id, msg.content)
```

### Event Subscriptions

Subscribe to channel events:

```elixir
# Subscribe to channel messages
channel_topic = "channel:#{channel_id}"
Phoenix.PubSub.subscribe(JidoChat.PubSub, channel_topic)

# Handle incoming messages
def handle_info({:message, message}, state) do
  # Process the message
  IO.puts "New message: #{message.content}"
  {:noreply, state}
end
```

## Error Handling

Implement proper error handling:

```elixir
case JidoChat.post_message(channel, participant_id, content) do
  {:ok, message} ->
    # Message sent successfully
    process_message(message)
    
  {:error, :invalid_participant} ->
    Logger.warning("Invalid participant attempted to post",
      participant_id: participant_id
    )
    
  {:error, :not_participants_turn} ->
    Logger.info("Not participant's turn to post",
      participant_id: participant_id
    )
    
  {:error, reason} ->
    Logger.error("Failed to post message",
      reason: reason,
      participant_id: participant_id
    )
end
```

For more detailed information, please refer to the [module documentation](https://hexdocs.pm/jido_chat).