defmodule JidoChat.Message do
  @moduledoc """
  Represents a chat message with metadata and type information.

  This module provides functionality for creating and managing chat messages with
  support for different message types (text, attachments, etc), participant tracking,
  and extensible metadata.

  ## Message Types

  The following message types are supported:
  - `:text` - Standard text messages
  - `:attachment` - File attachments
  - `:audio` - Audio messages
  - `:system` - System notifications and events
  - `:reaction` - Message reactions/emojis
  - `:other` - Other message types

  ## Features

  - Message creation with automatic ID generation and timestamps
  - System message support for notifications
  - Extensible metadata storage
  - Participant tracking and verification
  - Type safety with comprehensive typespecs

  ## Examples

      # Create a basic text message
      {:ok, msg} = Message.create("Hello!", "user123")

      # Create a system notification
      {:ok, sys_msg} = Message.system_message("User joined")

      # Add metadata
      msg = Message.add_metadata(msg, :priority, :high)
  """

  @type message_type ::
          :text
          | :attachment
          | :audio
          | :system
          | :reaction
          | :other

  @typedoc """
  A message struct containing:
  - `id`: Unique message identifier
  - `content`: The message content/body
  - `type`: The message type (see `t:message_type/0`)
  - `participant_id`: ID of the message sender
  - `timestamp`: When the message was created
  - `metadata`: Additional message metadata
  """
  @type t :: %__MODULE__{
          id: String.t(),
          content: String.t(),
          type: message_type(),
          participant_id: String.t(),
          timestamp: DateTime.t(),
          metadata: map()
        }

  defstruct [:id, :content, :type, :participant_id, :timestamp, metadata: %{}]

  @doc """
  Creates a new message with the given content and participant ID.

  Automatically sets the type to :text unless specified in options.
  Generates a UUID and timestamp if not provided.

  ## Parameters

    * `content` - The message content/body
    * `participant_id` - ID of the message sender
    * `opts` - Optional keyword list of message attributes

  ## Options

    * `:type` - The message type (default: `:text`)
    * `:metadata` - Additional metadata for the message (default: `%{}`)
    * `:id` - Custom ID for the message (default: generated UUID)
    * `:timestamp` - Custom timestamp (default: current UTC time)

  ## Returns

    * `{:ok, message}` - Successfully created message
    * `{:error, :invalid_message_type}` - If type is invalid

  ## Examples

      iex> create("Hello!", "user1")
      {:ok, %JidoChat.Message{content: "Hello!", participant_id: "user1", type: :text}}

      iex> create("file.jpg", "user1", type: :attachment)
      {:ok, %JidoChat.Message{content: "file.jpg", participant_id: "user1", type: :attachment}}

      iex> create("Hello!", "user1", type: :invalid)
      {:error, :invalid_message_type}
  """
  @spec create(String.t(), String.t(), keyword()) :: {:ok, t()} | {:error, :invalid_message_type}
  def create(content, participant_id, opts \\ [])
      when is_binary(content) and is_binary(participant_id) do
    type = Keyword.get(opts, :type, :text)
    metadata = Keyword.get(opts, :metadata, %{})

    valid_types = [:text, :attachment, :audio, :system, :reaction, :other]

    if type in valid_types do
      message = %__MODULE__{
        id: Keyword.get(opts, :id, UUID.uuid4()),
        content: content,
        type: type,
        participant_id: participant_id,
        timestamp: Keyword.get(opts, :timestamp, DateTime.utc_now()),
        metadata: metadata
      }

      {:ok, message}
    else
      {:error, :invalid_message_type}
    end
  end

  @doc """
  Creates a new system message.

  System messages are special messages used for notifications and events.
  They default to using "system" as the participant ID.

  ## Parameters

    * `content` - The system message content
    * `participant_id` - Optional custom participant ID (default: "system")

  ## Returns

    * `{:ok, message}` - The created system message

  ## Examples

      iex> system_message("User joined the chat")
      {:ok, %JidoChat.Message{content: "User joined the chat", type: :system, participant_id: "system"}}

      iex> system_message("Channel archived", "admin")
      {:ok, %JidoChat.Message{content: "Channel archived", type: :system, participant_id: "admin"}}
  """
  @spec system_message(String.t(), String.t()) :: {:ok, t()}
  def system_message(content, participant_id \\ "system") do
    create(content, participant_id, type: :system)
  end

  @doc """
  Adds metadata to an existing message.

  Allows attaching additional information to messages after creation.
  The key must be an atom.

  ## Parameters

    * `message` - The message to update
    * `key` - Atom key for the metadata
    * `value` - Value to store under the key

  ## Returns

    * Updated message with new metadata

  ## Examples

      iex> {:ok, msg} = create("Hello!", "user1")
      iex> msg = add_metadata(msg, :priority, :high)
      iex> msg.metadata.priority
      :high
  """
  @spec add_metadata(t(), atom(), term()) :: t()
  def add_metadata(%__MODULE__{} = message, key, value) when is_atom(key) do
    %{message | metadata: Map.put(message.metadata, key, value)}
  end

  @doc """
  Checks if a message was sent by a specific participant.

  ## Parameters

    * `message` - The message to check
    * `participant_id` - The participant ID to compare against

  ## Returns

    * `true` if the message is from the participant
    * `false` otherwise

  ## Examples

      iex> {:ok, msg} = create("Hello!", "user1")
      iex> from_participant?(msg, "user1")
      true
      iex> from_participant?(msg, "user2")
      false
  """
  @spec from_participant?(t(), String.t()) :: boolean()
  def from_participant?(%__MODULE__{} = message, participant_id) do
    message.participant_id == participant_id
  end
end
