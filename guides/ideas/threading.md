# JidoChat Thread Support Change Document

## 1. Overview

Add support for message threading, allowing participants to create conversation threads under any message while maintaining support for all existing message types and features.

## 2. Message Structure Changes

### 2.1 Message Extension
```elixir
defmodule JidoChat.Message do
  defstruct [
    :id,
    :type,
    :content,
    :participant_id,
    :timestamp,
    :thread_id,      # Added: ID of parent message if this is a thread reply
    :reply_count,    # Added: Count of replies in thread
    :last_reply_at,  # Added: Timestamp of most recent reply
    metadata: %{}
  ]

  def create_thread_reply(parent_message, content, participant_id) do
    with {:ok, message} <- create(content, participant_id) do
      {:ok, %{message | thread_id: parent_message.id}}
    end
  end
end
```

### 2.2 Thread Structure
```elixir
defmodule JidoChat.Thread do
  @type t :: %__MODULE__{
    parent_message: Message.t(),
    replies: [Message.t()],
    participant_count: non_neg_integer(),
    metadata: map()
  }

  defstruct [
    :parent_message,
    replies: [],
    participant_count: 0,
    metadata: %{}
  ]
end
```

## 3. Channel Extension

### 3.1 Channel Changes
```elixir
defmodule JidoChat.Channel do
  defstruct [
    # Existing fields...
    threads: %{},  # Map of message_id to Thread
    thread_participants: %{}  # Map of thread_id to participant set
  ]

  def reply_to_message(channel, parent_id, content, participant_id) do
    with {:ok, parent} <- get_message(channel, parent_id),
         {:ok, reply} <- Message.create_thread_reply(parent, content, participant_id),
         {:ok, thread} <- add_reply_to_thread(channel, parent, reply) do
      persist_thread_update(channel, thread)
    end
  end

  def get_thread(channel, message_id, opts \\ []) do
    with {:ok, thread} <- Map.fetch(channel.threads, message_id) do
      format_thread(thread, opts)
    end
  end
end
```

## 4. Persistence Changes

### 4.1 Ecto Schema Updates
```elixir
defmodule JidoChat.Persistence.Ecto.Message do
  use Ecto.Schema
  
  schema "messages" do
    # Existing fields...
    field :thread_id, :string
    field :reply_count, :integer, default: 0
    field :last_reply_at, :utc_datetime
    
    has_many :replies, __MODULE__, foreign_key: :thread_id
    belongs_to :parent, __MODULE__, foreign_key: :thread_id, define_field: false
  end
end
```

### 4.2 Thread Loading
```elixir
defmodule JidoChat.Channel.Persistence.Ecto do
  def load_thread(message_id, opts \\ []) do
    window_size = Keyword.get(opts, :window_size, 50)
    
    Message
    |> where([m], m.thread_id == ^message_id)
    |> order_by([m], asc: m.inserted_at)
    |> limit(^window_size)
    |> Repo.all()
  end
end
```

## 5. Message Behavior Updates

### 5.1 Thread-Aware Message Types
```elixir
defmodule JidoChat.Message.Behaviour do
  @callback type() :: atom()
  @callback validate(map()) :: {:ok, map()} | {:error, term()}
  @callback format_for_conversation(map()) :: map()
  @callback format_for_thread(map()) :: map()  # Added for thread formatting
end
```

### 5.2 Event Support in Threads
```elixir
defmodule JidoChat.Message.Event.Typing do
  @behaviour JidoChat.Message.Behaviour
  
  defstruct [:state, :thread_id]  # Added thread_id for thread context
  
  @impl true
  def format_for_thread(content) do
    # Thread-specific formatting for typing events
    %{
      thread_id: content.thread_id,
      state: content.state,
      context: :thread
    }
  end
end
```

## 6. Channel Integration

### 6.1 Message Pipeline
```elixir
defmodule JidoChat.Channel do
  def handle_message(%{thread_id: thread_id} = message, state) when not is_nil(thread_id) do
    with {:ok, thread} <- validate_thread(state, thread_id),
         {:ok, processed} <- process_thread_message(message, thread),
         {:ok, new_state} <- update_thread_state(state, processed) do
      broadcast_thread_update(new_state, processed)
      {:ok, new_state}
    end
  end

  def handle_message(message, state), do: handle_channel_message(message, state)
end
```

## 7. Feature Requirements

### 7.1 Threading Capabilities
- Create thread from any message
- Reply to threads with any message type
- Track thread participants
- Message type awareness in threads
- Thread status tracking

### 7.2 Thread Management
- Thread pagination
- Participant tracking
- Unread tracking per thread
- Thread summarization
- Thread activity metrics

### 7.3 Event Handling
- Thread-specific events (typing, etc.)
- Thread activity notifications
- Thread moderation support
- Thread state synchronization

## 8. Implementation Requirements

### 8.1 Thread Operations
- Thread creation
- Reply management
- Participant tracking
- State consistency
- Event propagation

### 8.2 Persistence Requirements
- Efficient thread loading
- Thread state caching
- Reply windowing
- Activity tracking

### 8.3 Performance Considerations
- Thread loading optimization
- Cache management
- State synchronization
- Event propagation

## 9. Testing Requirements

### 9.1 Functional Testing
- Thread creation
- Reply management
- Event handling
- State management

### 9.2 Integration Testing
- Message type compatibility
- Event propagation
- State consistency
- Cache behavior

## 10. Migration Support

### 10.1 Data Migration
- Add thread support to existing messages
- Update persistence layer
- Cache adaptation
- State transformation

### 10.2 Runtime Support
- Backwards compatibility
- Feature detection
- Graceful degradation
- State recovery