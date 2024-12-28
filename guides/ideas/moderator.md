# JidoChat Moderator Integration Change Document

## 1. Overview

Add support for dedicated moderator agents that can monitor multiple channels, enforce rules, and take administrative actions. Moderators are implemented as specialized Jido.Agent instances with elevated privileges and specific moderation actions.

## 2. Core Changes

### 2.1 Moderator Agent
```elixir
defmodule JidoChat.ModeratorAgent do
  @moduledoc """
  A specialized agent that provides channel moderation capabilities.
  Can monitor and moderate multiple channels simultaneously.
  """
  
  use Jido.Agent,
    name: "ModeratorAgent",
    schema: [
      channels: [type: {:map, String.t(), :map}, default: %{}],  # channel_id => channel_state
      active: [type: :boolean, default: true],
      rules: [type: {:map, String.t(), :any}, default: %{}]  # channel_id => rules
    ],
    actions: [
      JidoChat.Actions.Moderate.Monitor,
      JidoChat.Actions.Moderate.Warn,
      JidoChat.Actions.Moderate.Remove,
      JidoChat.Actions.Moderate.Mute
    ]
end
```

## 3. Moderation Actions

### 3.1 Monitor Action
```elixir
defmodule JidoChat.Actions.Moderate.Monitor do
  use Jido.Action,
    name: "monitor",
    description: "Monitors channel messages",
    schema: [
      channel_id: [type: :string, required: true],
      message: [type: :map, required: true],
      context: [type: :map, default: %{}]
    ]

  @impl true
  def run(%{channel_id: channel_id, message: message}, state) do
    with {:ok, analysis} <- analyze_content(message, state),
         {:ok, action} <- determine_action(analysis, state.rules[channel_id]) do
      {:ok, %{analysis: analysis, action: action}}
    end
  end
end
```

### 3.2 Enforcement Actions
```elixir
defmodule JidoChat.Actions.Moderate.Warn do
  use Jido.Action,
    name: "warn",
    schema: [
      channel_id: [type: :string, required: true],
      participant_id: [type: :string, required: true],
      reason: [type: :string, required: true]
    ]
end

defmodule JidoChat.Actions.Moderate.Mute do
  use Jido.Action,
    name: "mute",
    schema: [
      channel_id: [type: :string, required: true],
      participant_id: [type: :string, required: true],
      duration: [type: :integer, required: true],
      reason: [type: :string, required: true]
    ]
end

defmodule JidoChat.Actions.Moderate.Remove do
  use Jido.Action,
    name: "remove",
    schema: [
      channel_id: [type: :string, required: true],
      participant_id: [type: :string, required: true],
      reason: [type: :string, required: true]
    ]
end
```

## 4. Channel Integration

### 4.1 Channel Extension
```elixir
defmodule JidoChat.Channel do
  defstruct [
    # Existing fields...
    moderator_id: nil,
    moderation_settings: %{}
  ]

  def handle_message(%{moderator_id: mod_id} = channel, message) when not is_nil(mod_id) do
    with {:ok, processed} <- process_message(message),
         :ok <- notify_moderator(mod_id, channel.id, processed) do
      {:ok, processed}
    end
  end
end
```

## 5. Feature Requirements

### 5.1 Core Capabilities
- Single moderator can monitor multiple channels
- Real-time message analysis and action
- Graduated response system (warn → mute → remove)
- Per-channel rule configuration
- Action logging and tracking

### 5.2 Monitoring Features
- Message content analysis
- Pattern detection
- Simple rule enforcement
- Action tracking per participant

### 5.3 Action System
- Warning system
- Temporary muting
- Participant removal
- Action logging

## 6. Implementation Details

### 6.1 Message Flow
1. Channel receives message
2. Message processed normally
3. Moderator agent notified
4. Content analyzed against rules
5. Actions determined and applied
6. Results logged

### 6.2 Multi-Channel Support
1. Moderator maintains channel map
2. Per-channel configuration
3. Independent rule sets
4. Separate action tracking

### 6.3 Rule Processing
- Simple rule definition
- Rule validation
- Action determination
- Rule enforcement

## 7. Testing Requirements

### 7.1 Unit Tests
- Action implementations
- Rule processing
- Message analysis
- State management

### 7.2 Integration Tests
- Channel integration
- Multi-channel scenarios
- Action application
- State consistency

## 8. Documentation Requirements

### 8.1 Usage Documentation
- Moderator setup
- Rule configuration
- Action handling
- Integration guide

### 8.2 Development Guide
- Action implementation
- Rule creation
- Custom analyzers
- State management