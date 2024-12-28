# JidoChat Rich Messages Change Document

## 1. Message System Changes

### 1.1 Message Behavior
```elixir
defmodule JidoChat.Message.Behaviour do
  @callback type() :: atom()
  @callback validate(map()) :: {:ok, map()} | {:error, term()}
  @callback format_for_conversation(map()) :: map()
end
```

### 1.2 Core Message Structure
```elixir
defmodule JidoChat.Message do
  @type t :: %__MODULE__{
    id: String.t(),
    type: module(),           # The implementing message type module
    content: map(),           # Type-specific content structure
    participant_id: String.t(),
    timestamp: DateTime.t(),
    metadata: map()
  }
  
  defstruct [:id, :type, :content, :participant_id, :timestamp, metadata: %{}]
end
```

### 1.3 Example Message Types

#### Text Message
```elixir
defmodule JidoChat.Message.Text do
  @behaviour JidoChat.Message.Behaviour
  
  defstruct [:content, :formatting]
  
  @impl true
  def type(), do: :text
  
  @impl true
  def validate(content) do
    # Validation logic
  end
  
  @impl true
  def format_for_conversation(content) do
    # Formatting logic
  end
end
```

#### Typing Event
```elixir
defmodule JidoChat.Message.Event.Typing do
  @behaviour JidoChat.Message.Behaviour
  
  defstruct [:state]  # :started or :stopped
  
  @impl true
  def type(), do: :typing
  
  @impl true
  def validate(%{state: state}) when state in [:started, :stopped] do
    # Validation logic
  end
  
  @impl true
  def format_for_conversation(content) do
    # Formatting logic
  end
end
```

#### Attachment Message
```elixir
defmodule JidoChat.Message.Attachment do
  @behaviour JidoChat.Message.Behaviour
  
  defstruct [:content_type, :data, :metadata]
  
  @impl true
  def type(), do: :attachment
  
  @impl true
  def validate(content) do
    # Validation logic for attachments
  end
  
  @impl true
  def format_for_conversation(content) do
    # Formatting logic for attachments
  end
end
```

## 2. API Changes

### 2.1 Message Creation
```elixir
defmodule JidoChat do
  @spec create_message(channel_id(), participant_id(), struct()) :: 
    {:ok, Message.t()} | {:error, term()}
    
  @spec handle_attachment(channel_id(), participant_id(), struct()) ::
    {:ok, Message.t()} | {:error, term()}
end
```

### 2.2 Channel Extensions
```elixir
defmodule JidoChat.Channel do
  @spec handle_message(pid(), Message.t()) :: :ok | {:error, term()}
  @spec process_attachment(pid(), Message.t()) :: :ok | {:error, term()}
end
```

## 3. Conversation Integration

### 3.1 Conversation Formatting
```elixir
defmodule JidoChat.Conversation do
  @spec format_message(Message.t(), [Participant.t()]) :: map()
end
```

## 4. Implementation Requirements

### 4.1 Message Handling
- Generic message validation framework
- Type-specific content validation
- Flexible metadata support
- Attachment processing pipeline

### 4.2 Event Processing
- Real-time event broadcasting
- Generic event state management
- Event acknowledgment system

## 5. Testing Requirements

### 5.1 Message Type Testing
- Behavior implementation tests
- Message type validation tests
- Content format validation
- Integration tests

### 5.2 Attachment Testing
- Content type handling tests
- Attachment processing tests
- Error handling scenarios

## 6. Documentation Requirements

### 6.1 Developer Documentation
- Message behavior implementation guide
- New message type creation guide
- Attachment handling guide
- Event system integration guide