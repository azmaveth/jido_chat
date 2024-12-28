# JidoChat Participant Reference Change Document

## 1. Overview

Add support for participant references (@mentions) in messages as an intrinsic part of message processing, allowing messages to indicate specific intended recipients while remaining visible to all channel participants.

## 2. Core Changes

### 2.1 Reference Structure
```elixir
defmodule JidoChat.ParticipantRef do
  @type t :: %__MODULE__{
    participant_id: String.t(),
    display_name: String.t(),
    ref_type: :mention | :reply | :thread,
    offset: non_neg_integer(),  # Position in message content
    length: non_neg_integer()   # Length of reference in content
  }
  
  defstruct [:participant_id, :display_name, :ref_type, :offset, :length]
end
```

### 2.2 Message Extension
```elixir
defmodule JidoChat.Message do
  @type t :: %__MODULE__{
    id: String.t(),
    type: module(),
    content: map(),
    participant_id: String.t(),
    timestamp: DateTime.t(),
    refs: [ParticipantRef.t()],  # Added field
    metadata: map()
  }
  
  defstruct [:id, :type, :content, :participant_id, :timestamp, refs: [], metadata: %{}]
end
```

## 3. Behavior Changes

### 3.1 Message Behavior Extension
```elixir
defmodule JidoChat.Message.Behaviour do
  @callback type() :: atom()
  @callback validate(map()) :: {:ok, map()} | {:error, term()}
  @callback format_for_conversation(map()) :: map()
  @callback process_content(String.t(), [Participant.t()]) :: {:ok, map()} | {:error, term()}
end
```

### 3.2 Example Implementation
```elixir
defmodule JidoChat.Message.Text do
  @behaviour JidoChat.Message.Behaviour
  
  @impl true
  def process_content(content, participants) do
    # Automatically extract and validate refs from content
    with {:ok, processed_content, refs} <- extract_and_validate_refs(content, participants) do
      {:ok, %{
        content: processed_content,
        refs: refs
      }}
    end
  end
  
  @impl true
  def format_for_conversation(message) do
    # References are automatically included in formatting
    %{
      text: message.content,
      formatted_text: format_with_refs(message.content, message.refs)
    }
  end
end
```

## 4. Channel Extensions

### 4.1 Internal Reference Handling
```elixir
defmodule JidoChat.Channel do
  # Internal function to process messages and handle references
  defp process_message(message, state) do
    with {:ok, processed_message} <- validate_message_content(message, state.participants),
         :ok <- notify_referenced_participants(processed_message) do
      {:ok, processed_message}
    end
  end
end
```

## 5. Feature Requirements

### 5.1 Reference Processing
- Automatic parsing of @mentions from message content
- Transparent validation of referenced participants
- Support for multiple references per message
- Reference metadata tracking (position, type)
- Automatic handling of participant name changes

### 5.2 Notification Requirements
- Automatic notification of referenced participants
- Configurable notification preferences
- Transparent reference acknowledgment tracking

### 5.3 Display Requirements
- Automatic highlighting of references in formatted content
- Reference type indication in display
- Graceful handling of invalid references

### 5.4 Query Support
- Standard message queries automatically include reference information
- Reference-aware message filtering
- Time and context-aware querying

## 6. Testing Requirements

### 6.1 Functional Testing
- Content processing with references
- Reference extraction and validation
- Notification delivery
- Message formatting with references

### 6.2 Integration Testing
- End-to-end message flow with references
- Multiple reference scenarios
- Reference persistence
- Notification system integration

## 7. Documentation Requirements

### 7.1 User Documentation
- Reference syntax guide
- Notification behavior explanation
- Reference types and usage

### 7.2 Developer Documentation
- Message processing pipeline
- Reference handling implementation
- Custom message type creation
- Best practices for reference handling