defmodule JidoChat do
  @moduledoc """
  JidoChat is a structured chat channel system supporting human and agent participants
  with customizable turn-taking strategies and persistence.

  ## Features

  - Multiple persistence adapters (ETS, Agent-based memory store)
  - Flexible turn-taking strategies
  - Support for human and AI agent participants
  - Message history management
  - Conversation context extraction for LLMs
  """

  alias JidoChat.{Channel, Participant, Message, Conversation}

  @type channel_id :: String.t()
  @type participant_id :: String.t()
  @type error :: {:error, term()}

  @doc """
  Creates a new chat channel with the specified options.

  ## Options

    * `:strategy` - The turn-taking strategy module (default: Strategy.FreeForm)
    * `:message_limit` - Maximum number of messages to retain (default: 1000)
    * `:persistence` - Persistence adapter to use (default: Persistence.ETS)
    * `:name` - Channel name (default: generated from channel_id)

  ## Examples

      iex> {:ok, pid} = JidoChat.create_channel("channel-123", strategy: JidoChat.Channel.Strategy.RoundRobin)
      {:ok, pid}
  """
  @spec create_channel(channel_id(), keyword()) :: {:ok, pid()} | error()
  def create_channel(channel_id, opts \\ []) do
    Channel.start_link(channel_id, opts)
  end

  @doc """
  Adds a participant to a channel.

  ## Examples

      iex> {:ok, channel_pid} = JidoChat.create_channel("channel-123")
      iex> participant = %JidoChat.Participant{id: "user1", name: "Alice", type: :human}
      iex> JidoChat.join_channel(channel_pid, participant)
      :ok
  """
  @spec join_channel(pid(), Participant.t()) :: :ok | error()
  def join_channel(channel_pid, participant) do
    Channel.join(channel_pid, participant)
  end

  @doc """
  Posts a message to a channel.

  ## Examples

    iex> {:ok, channel_pid} = JidoChat.create_channel("channel-123")
    iex> JidoChat.post_message(channel_pid, "user1", "Hello!")
    {:ok, %JidoChat.Message{}}
  """
  @spec post_message(pid(), participant_id(), String.t()) :: {:ok, Message.t()} | error()
  def post_message(channel_pid, participant_id, content) do
    Channel.post_message(channel_pid, participant_id, content)
  end

  @doc """
  Creates a conversation context from recent messages suitable for LLM processing.

  ## Options

    * `:message_limit` - Maximum number of messages to include (default: 10)
    * `:include_metadata` - Whether to include message metadata (default: false)
    * `:format` - Conversation format (:chat_ml | :anthropic | :raw) (default: :chat_ml)

  ## Examples

    iex> {:ok, channel_pid} = JidoChat.create_channel("channel-123")
    iex> JidoChat.get_conversation_context(channel_pid, limit: 5)
    {:ok, %JidoChat.Conversation{}}
  """
  @spec get_conversation_context(pid(), keyword()) :: {:ok, Conversation.t()} | error()
  def get_conversation_context(channel_pid, opts \\ []) do
    with {:ok, messages} <- Channel.get_messages(channel_pid),
         {:ok, participants} <- Channel.get_participants(channel_pid) do
      Conversation.from_messages(messages, participants, opts)
    end
  end
end
