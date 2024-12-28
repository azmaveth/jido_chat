defmodule JidoChat.Channel do
  @moduledoc """
  Manages chat channel state and behavior using GenServer.

  This module implements the core chat channel functionality, managing message history,
  participants, turn-taking, and message persistence. It uses a GenServer process to
  maintain channel state and coordinate communication between participants.

  ## Features

  - Message posting and history management with configurable limits
  - Participant join/leave management
  - Pluggable turn-taking strategies
  - Configurable message persistence
  - PubSub-based message broadcasting
  - Participant presence tracking

  ## State Management

  Channel state is maintained in a struct containing:
  - Channel ID and name
  - List of participants
  - Message history with configurable limit
  - Current turn and turn-taking strategy
  - Message broker PID for PubSub
  - Persistence adapter configuration
  - Custom metadata

  ## Usage

      # Create a new channel
      {:ok, pid} = Channel.start_link("channel-123", strategy: Strategy.RoundRobin)

      # Add a participant
      :ok = Channel.join(pid, participant)

      # Post a message
      {:ok, message} = Channel.post_message(pid, "user-123", "Hello!")

      # Get message history
      {:ok, messages} = Channel.get_messages(pid, order: :chronological)

  ## Configuration

  The channel can be configured with:
  - Turn-taking strategy module
  - Message history limit
  - Persistence adapter
  - Custom metadata
  """

  use GenServer
  require Logger
  alias JidoChat.{Message, PubSub}
  alias Phoenix.PubSub, as: PhoenixPubSub

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          participants: [JidoChat.Participant.t()],
          messages: [JidoChat.Message.t()],
          turn_strategy: module(),
          current_turn: String.t() | nil,
          message_limit: non_neg_integer(),
          metadata: map(),
          persistence_adapter: module(),
          message_broker: pid()
        }
  @type channel_error ::
          :invalid_participant
          | :not_participants_turn
          | :message_too_large
          | :channel_full
  @enforce_keys [:id, :name]
  defstruct [
    :id,
    :name,
    :message_broker,
    participants: [],
    messages: [],
    turn_strategy: JidoChat.Channel.Strategy.PubSubRoundRobin,
    current_turn: nil,
    metadata: %{},
    message_limit: 1000,
    persistence_adapter: JidoChat.Channel.Persistence.ETS
  ]

  @doc """
  Returns child specification for supervision tree.

  ## Options

  - `:name` - Required channel ID for registration
  - All other options are passed to `start_link/2`

  ## Returns

  Standard child specification map with:
  - Unique ID based on channel ID
  - Permanent restart strategy
  - 500ms shutdown timeout
  """
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    channel_id = Keyword.fetch!(opts, :name)

    %{
      id: {__MODULE__, channel_id},
      start: {__MODULE__, :start_link, [channel_id, opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  # Client API

  @doc """
  Starts a new channel process linked to the current process.

  ## Options

  - `:strategy` - Turn-taking strategy module (default: Strategy.PubSubRoundRobin)
  - `:message_limit` - Max messages to retain (default: 1000)
  - `:persistence_adapter` - Storage adapter module (default: Persistence.ETS)

  ## Returns

  - `{:ok, pid}` on success
  - `{:error, reason}` on failure
  """
  @spec start_link(String.t(), keyword()) :: GenServer.on_start()
  def start_link(channel_id, opts \\ []) do
    GenServer.start_link(__MODULE__, {channel_id, opts}, name: via_tuple(channel_id))
  end

  @doc """
  Posts a message to the channel from a participant.

  Validates that:
  - Participant exists in channel
  - It is participant's turn (if turn-taking enabled)
  - Message content is valid

  ## Parameters

  - `channel` - Channel PID or ID
  - `participant_id` - ID of participant sending message
  - `content` - Message content string

  ## Returns

  - `{:ok, message}` on success
  - `{:error, reason}` if validation fails
  """
  @spec post_message(pid() | String.t(), String.t(), String.t()) ::
          {:ok, Message.t()} | {:error, channel_error()}
  def post_message(channel, participant_id, content) do
    GenServer.call(get_channel_ref(channel), {:post_message, participant_id, content})
  end

  @doc """
  Adds a participant to the channel.

  Registers the participant with the message broker and adds them to channel state.

  ## Parameters

  - `channel` - Channel PID or ID
  - `participant` - Participant struct to add

  ## Returns

  - `:ok` on successful join
  - `{:ok, :already_joined}` if already a member
  """
  @spec join(pid() | String.t(), JidoChat.Participant.t()) :: :ok | {:ok, :already_joined}
  def join(channel, participant) do
    GenServer.call(get_channel_ref(channel), {:join, participant})
  end

  @doc """
  Removes a participant from the channel.

  Unregisters from message broker and removes from channel state.

  ## Parameters

  - `channel` - Channel PID or ID
  - `participant_id` - ID of participant to remove

  ## Returns

  - `:ok` on successful removal
  """
  @spec leave(pid() | String.t(), String.t()) :: :ok
  def leave(channel, participant_id) do
    GenServer.call(get_channel_ref(channel), {:leave, participant_id})
  end

  @doc """
  Gets channel messages with optional ordering.

  ## Options

  - `:order` - `:chronological` (oldest first) or `:reverse_chronological` (newest first)
    Default: `:chronological`

  ## Returns

  - `{:ok, messages}` List of message structs in requested order
  """
  @spec get_messages(pid() | String.t(), keyword()) :: {:ok, [Message.t()]}
  def get_messages(channel, opts \\ []) do
    order = Keyword.get(opts, :order, :chronological)
    GenServer.call(get_channel_ref(channel), {:get_messages, order})
  end

  @doc """
  Gets list of channel participants.

  ## Parameters

  - `channel` - Channel PID or ID
  - `type` - Optional participant type filter (:all, :human, or :agent). Defaults to :all

  ## Returns

  - `{:ok, participants}` List of participant structs filtered by type if specified
  """
  @spec get_participants(pid() | String.t(), :all | :human | :agent) ::
          {:ok, [JidoChat.Participant.t()]}
  def get_participants(channel, type \\ :all) do
    GenServer.call(get_channel_ref(channel), {:get_participants, type})
  end

  # Private Functions

  # Converts a channel reference (PID or ID) to appropriate process reference
  #
  # ## Parameters
  #
  # - `channel` - Channel PID, string ID, or atom ID
  #
  # ## Returns
  #
  # - PID if input is PID
  # - Via tuple for Registry if input is string/atom ID
  @spec get_channel_ref(pid() | String.t() | atom()) ::
          pid() | {:via, Registry, {atom(), String.t()}}
  defp get_channel_ref(channel) when is_binary(channel) or is_atom(channel),
    do: via_tuple(channel)

  defp get_channel_ref(pid) when is_pid(pid), do: pid

  # Server Callbacks

  @impl true
  def init({channel_id, opts}) do
    strategy = Keyword.get(opts, :strategy, JidoChat.Channel.Strategy.PubSubRoundRobin)
    message_limit = Keyword.get(opts, :message_limit, 1000)

    # Start the message broker for this channel
    case PubSub.MessageBroker.start_link(
           channel_id: channel_id,
           strategy: strategy
         ) do
      {:ok, broker_pid} ->
        # Subscribe to the channel's topic
        channel_topic = "channel:#{channel_id}"
        :ok = PhoenixPubSub.subscribe(JidoChat.PubSub, channel_topic)

        # Load or create channel state
        {:ok, channel} = JidoChat.Channel.Persistence.load_or_create(channel_id)

        channel = %{
          channel
          | turn_strategy: strategy,
            current_turn: nil,
            message_broker: broker_pid,
            message_limit: message_limit
        }

        {:ok, channel}

      {:error, reason} ->
        Logger.warning(
          "Failed to start message broker for channel #{channel_id}: #{inspect(reason)}"
        )

        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:post_message, participant_id, content}, _from, channel) do
    with true <- has_participant?(channel, participant_id),
         true <- channel.turn_strategy.can_post?(channel, participant_id) do
      message = create_message(participant_id, content)

      # Broadcast through the message broker
      PubSub.MessageBroker.broadcast(
        channel.message_broker,
        "channel:#{channel.id}",
        message
      )

      updated_channel = add_message_to_channel(channel, message)
      updated_channel = channel.turn_strategy.next_turn(updated_channel)

      :ok =
        JidoChat.Channel.Persistence.save(
          channel.id,
          updated_channel,
          channel.persistence_adapter
        )

      {:reply, {:ok, message}, updated_channel}
    else
      false ->
        {:reply, {:error, :not_allowed}, channel}
    end
  end

  @impl true
  def handle_call({:join, participant}, _from, channel) do
    if has_participant?(channel, participant.id) do
      {:reply, {:ok, :already_joined}, channel}
    else
      # Register participant with message broker
      topic = participant_topic(channel.id, participant.id)

      :ok =
        PubSub.MessageBroker.register_participant(
          channel.message_broker,
          participant,
          topic
        )

      updated_channel = %{channel | participants: [participant | channel.participants]}

      :ok =
        JidoChat.Channel.Persistence.save(
          channel.id,
          updated_channel,
          channel.persistence_adapter
        )

      {:reply, :ok, updated_channel}
    end
  end

  @impl true
  def handle_call({:leave, participant_id}, _from, channel) do
    updated_participants = Enum.reject(channel.participants, &(&1.id == participant_id))
    updated_channel = %{channel | participants: updated_participants}

    :ok =
      JidoChat.Channel.Persistence.save(channel.id, updated_channel, channel.persistence_adapter)

    {:reply, :ok, updated_channel}
  end

  @impl true
  def handle_call({:get_messages, order}, _from, channel) do
    messages =
      case order do
        # oldest first
        :chronological -> Enum.reverse(channel.messages)
        # newest first
        :reverse_chronological -> channel.messages
      end

    {:reply, {:ok, messages}, channel}
  end

  @impl true
  def handle_call({:get_participants, type}, _from, channel) do
    participants =
      case type do
        :all ->
          channel.participants

        type when type in [:human, :agent] ->
          Enum.filter(channel.participants, &(&1.type == type))
      end

    {:reply, {:ok, participants}, channel}
  end

  @impl true
  def handle_info({:message, message}, channel) do
    if Enum.any?(channel.messages, &(&1.id == message.id)) do
      {:noreply, channel}
    else
      updated_channel = add_message_to_channel(channel, message)
      {:noreply, updated_channel}
    end
  end

  # Private Functions

  # Generates a participant-specific topic string for PubSub
  #
  # ## Parameters
  #
  # - `channel_id` - Channel identifier
  # - `participant_id` - Participant identifier
  #
  # ## Returns
  #
  # Topic string in format "channel:{channel_id}:participant:{participant_id}"
  @spec participant_topic(String.t(), String.t()) :: String.t()
  defp participant_topic(channel_id, participant_id) do
    "channel:#{channel_id}:participant:#{participant_id}"
  end

  # Checks if a participant exists in the channel
  #
  # ## Parameters
  #
  # - `channel` - Channel struct
  # - `participant_id` - ID to check
  #
  # ## Returns
  #
  # Boolean indicating if participant exists
  @spec has_participant?(t(), String.t()) :: boolean()
  defp has_participant?(channel, participant_id) do
    Enum.any?(channel.participants, &(&1.id == participant_id))
  end

  # Creates a new message struct for the given participant and content
  #
  # ## Parameters
  #
  # - `participant_id` - ID of message sender
  # - `content` - Message content string
  #
  # ## Returns
  #
  # New Message struct or raises on validation failure
  @spec create_message(String.t(), String.t()) :: Message.t()
  defp create_message(participant_id, content) do
    case Message.create(content, participant_id) do
      {:ok, message} -> message
      {:error, _reason} -> raise "Failed to create message"
    end
  end

  # Adds a message to the channel's message history, respecting message limit
  #
  # ## Parameters
  #
  # - `channel` - Channel struct
  # - `message` - Message to add
  #
  # ## Returns
  #
  # Updated channel struct with message added and possibly older messages pruned
  defp add_message_to_channel(channel, message) do
    messages = [message | channel.messages]

    limited_messages =
      case channel.message_limit do
        nil ->
          messages

        limit when is_integer(limit) and limit > 0 ->
          Enum.take(messages, limit)
      end

    :ok =
      JidoChat.Channel.Persistence.save(
        channel.id,
        %{channel | messages: limited_messages},
        channel.persistence_adapter
      )

    %{channel | messages: limited_messages}
  end

  # Creates a via tuple for Registry registration
  #
  # ## Parameters
  #
  # - `channel_id` - Channel identifier
  #
  # ## Returns
  #
  # Via tuple for Registry registration
  @spec via_tuple(String.t()) :: {:via, Registry, {atom(), String.t()}}
  defp via_tuple(channel_id) do
    {:via, Registry, {JidoChat.ChannelRegistry, channel_id}}
  end
end
