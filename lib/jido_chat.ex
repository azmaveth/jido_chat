defmodule JidoChat do
  @moduledoc """
  JidoChat is a structured chat channel system supporting human and agent participants
  with customizable turn-taking strategies and persistence.

  ## Features

  - Multiple persistence adapters (ETS, Agent-based memory store)
  - Flexible turn-taking strategies (round-robin, free-form, moderated)
  - Support for human and AI agent participants
  - Message history management with configurable limits
  - Conversation context extraction optimized for LLMs
  - PubSub-based real-time message delivery
  - Extensible participant metadata

  ## Architecture

  The system is built around these core concepts:

  - Channels: Isolated chat rooms with their own participants and history
  - Participants: Human users or AI agents that can send/receive messages
  - Messages: Text content with metadata like timestamps and sender info
  - Strategies: Pluggable turn-taking rules governing conversation flow
  - Persistence: Adapters for storing channel state and history

  ## Usage

      # Create a new channel with round-robin turn taking
      {:ok, channel} = JidoChat.create_channel("channel-123",
        strategy: JidoChat.Channel.Strategy.RoundRobin,
        message_limit: 100
      )

      # Add participants
      participant = %Participant{id: "user1", name: "Alice", type: :human}
      :ok = JidoChat.join_channel(channel, participant)

      # Post messages
      {:ok, message} = JidoChat.post_message(channel, "user1", "Hello!")

      # Get conversation context for LLM
      {:ok, context} = JidoChat.get_conversation_context(channel,
        limit: 10,
        format: :chat_ml
      )

  ## Configuration

  The following configuration options are available:

      config :jido_chat,
        persistence: JidoChat.Channel.Persistence.ETS,
        default_message_limit: 1000,
        default_strategy: JidoChat.Channel.Strategy.FreeForm

  See `JidoChat.Channel` for detailed channel configuration options.
  """

  alias JidoChat.{Channel, Participant, Message, Conversation}

  @typedoc """
  Unique identifier for a chat channel.
  Must be a valid string containing only alphanumeric characters, hyphens and underscores.
  """
  @type channel_id :: String.t()

  @typedoc """
  Unique identifier for a participant within a channel.
  Must be a valid string containing only alphanumeric characters, hyphens and underscores.
  """
  @type participant_id :: String.t()

  @typedoc """
  Generic error tuple returned by operations that can fail.
  The error term provides more specific error information.
  """
  @type error :: {:error, term()}

  @typedoc """
  Specific validation errors that can occur during channel operations:

  - `:invalid_channel_id` - Channel ID format is invalid
  - `:invalid_participant` - Participant data is invalid or missing required fields
  - `:channel_exists` - Attempted to create a channel with an ID that already exists
  - `:channel_not_found` - The specified channel does not exist
  """
  @type validation_error ::
          :invalid_channel_id
          | :invalid_participant
          | :channel_exists
          | :channel_not_found

  @doc """
  Creates a new chat channel with the specified options.

  The channel ID must be unique across the system and contain only alphanumeric
  characters, hyphens and underscores. The channel is created with the specified
  turn-taking strategy, message limit and persistence adapter.

  ## Options

    * `:strategy` - The turn-taking strategy module (default: Strategy.FreeForm)
    * `:message_limit` - Maximum number of messages to retain (default: 1000)
    * `:persistence` - Persistence adapter to use (default: Persistence.ETS)
    * `:name` - Channel name (default: generated from channel_id)
    * `:metadata` - Additional channel metadata (default: %{})

  ## Examples

      # Create with default options
      {:ok, pid} = JidoChat.create_channel("channel-123")

      # Create with custom strategy and limit
      {:ok, pid} = JidoChat.create_channel("channel-456",
        strategy: JidoChat.Channel.Strategy.RoundRobin,
        message_limit: 500
      )

  ## Errors

    * `{:error, :invalid_channel_id}` - If channel ID format is invalid
    * `{:error, :channel_exists}` - If channel ID is already taken
  """
  @spec create_channel(channel_id(), keyword()) ::
          {:ok, pid()}
          | {:error, validation_error()}
  def create_channel(channel_id, opts \\ []) do
    Channel.start_link(channel_id, opts)
  end

  @doc """
  Adds a participant to a channel.

  The participant must have a valid ID and type. The participant will be able to
  send and receive messages according to the channel's turn-taking strategy.
  Duplicate participant IDs are not allowed within the same channel.

  ## Parameters

    * `channel_pid` - PID of the channel process
    * `participant` - Participant struct with ID, name, type and optional metadata

  ## Examples

      # Add a human participant
      participant = %Participant{
        id: "user1",
        name: "Alice",
        type: :human,
        metadata: %{avatar_url: "https://..."}
      }
      :ok = JidoChat.join_channel(channel_pid, participant)

      # Add an AI agent
      agent = %Participant{
        id: "agent1",
        name: "Assistant",
        type: :agent,
        metadata: %{capabilities: [:chat]}
      }
      :ok = JidoChat.join_channel(channel_pid, agent)

  ## Errors

    * `{:error, :invalid_participant}` - If participant data is invalid
    * `{:error, :participant_exists}` - If participant ID already exists in channel
  """
  @spec join_channel(pid(), Participant.t()) :: :ok | error()
  def join_channel(channel_pid, participant) do
    Channel.join(channel_pid, participant)
  end

  @doc """
  Posts a message to a channel.

  The message will be delivered according to the channel's turn-taking strategy.
  Messages are stored in the channel's history up to the configured message limit.
  All channel participants will receive the message via PubSub.

  ## Parameters

    * `channel_pid` - PID of the channel process
    * `participant_id` - ID of the participant sending the message
    * `content` - Text content of the message

  ## Examples

      # Post a simple message
      {:ok, msg} = JidoChat.post_message(channel_pid, "user1", "Hello!")

      # Post with rich content
      {:ok, msg} = JidoChat.post_message(channel_pid, "agent1",
        "Here's an image: ![cat](https://...)"
      )

  ## Errors

    * `{:error, :invalid_participant}` - If participant ID is invalid
    * `{:error, :not_participants_turn}` - If not participant's turn to post
    * `{:error, :message_too_large}` - If message exceeds size limit
  """
  @spec post_message(pid(), participant_id(), String.t()) :: {:ok, Message.t()} | error()
  def post_message(channel_pid, participant_id, content) do
    Channel.post_message(channel_pid, participant_id, content)
  end

  @doc """
  Creates a conversation context from recent messages suitable for LLM processing.

  Extracts recent messages and formats them according to the specified LLM format.
  Messages are ordered chronologically and include participant role information.
  Supports major LLM conversation formats including ChatML and Anthropic.

  ## Options

    * `:message_limit` - Maximum number of messages to include (default: 10)
    * `:include_metadata` - Whether to include message metadata (default: false)
    * `:format` - Conversation format (:chat_ml | :anthropic | :raw) (default: :chat_ml)
    * `:system_prompt` - Optional system prompt to prepend (default: nil)

  ## Examples

      # Get recent context in ChatML format
      {:ok, context} = JidoChat.get_conversation_context(channel_pid,
        limit: 5,
        format: :chat_ml
      )

      # Get context with system prompt
      {:ok, context} = JidoChat.get_conversation_context(channel_pid,
        system_prompt: "You are a helpful assistant",
        format: :anthropic
      )

  ## Errors

    * `{:error, :invalid_format}` - If conversation format is invalid
    * `{:error, :no_messages}` - If channel has no messages
  """
  @spec get_conversation_context(pid(), keyword()) :: {:ok, Conversation.t()} | error()
  def get_conversation_context(channel_pid, opts \\ []) do
    with {:ok, messages} <- Channel.get_messages(channel_pid),
         {:ok, participants} <- Channel.get_participants(channel_pid) do
      Conversation.from_messages(messages, participants, opts)
    end
  end
end
