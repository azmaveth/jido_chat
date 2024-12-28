defmodule JidoChat.Channel do
  @moduledoc """
  Manages chat channel state and behavior using GenServer.

  Provides functionality for:
  - Message posting and history
  - Participant management
  - Turn-taking strategies
  - Message persistence
  - PubSub message broadcasting
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
  """
  @spec start_link(String.t(), keyword()) :: GenServer.on_start()
  def start_link(channel_id, opts \\ []) do
    GenServer.start_link(__MODULE__, {channel_id, opts}, name: via_tuple(channel_id))
  end

  @doc """
  Posts a message to the channel from a participant.
  """
  @spec post_message(pid() | String.t(), String.t(), String.t()) ::
          {:ok, Message.t()} | {:error, atom()}
  def post_message(channel, participant_id, content) do
    GenServer.call(get_channel_ref(channel), {:post_message, participant_id, content})
  end

  @doc """
  Adds a participant to the channel.
  """
  @spec join(pid() | String.t(), JidoChat.Participant.t()) :: :ok | {:ok, :already_joined}
  def join(channel, participant) do
    GenServer.call(get_channel_ref(channel), {:join, participant})
  end

  @doc """
  Removes a participant from the channel.
  """
  @spec leave(pid() | String.t(), String.t()) :: :ok
  def leave(channel, participant_id) do
    GenServer.call(get_channel_ref(channel), {:leave, participant_id})
  end

  @doc """
  Gets channel messages with optional ordering.
  """
  @spec get_messages(pid() | String.t(), keyword()) :: {:ok, [Message.t()]}
  def get_messages(channel, opts \\ []) do
    order = Keyword.get(opts, :order, :chronological)
    GenServer.call(get_channel_ref(channel), {:get_messages, order})
  end

  @doc """
  Gets list of channel participants.
  """
  @spec get_participants(pid() | String.t()) :: {:ok, [JidoChat.Participant.t()]}
  def get_participants(channel) do
    GenServer.call(get_channel_ref(channel), :get_participants)
  end

  # Private helper to handle channel reference
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
    {:ok, broker_pid} =
      PubSub.MessageBroker.start_link(
        channel_id: channel_id,
        strategy: strategy
      )

    # Subscribe to the channel's topic
    channel_topic = "channel:#{channel_id}"
    :ok = PhoenixPubSub.subscribe(JidoChat.PubSub, channel_topic)

    case JidoChat.Channel.Persistence.load_or_create(channel_id) do
      {:ok, channel} ->
        channel = %{
          channel
          | turn_strategy: strategy,
            current_turn: nil,
            message_broker: broker_pid,
            message_limit: message_limit
        }

        {:ok, channel}

      {:error, reason} ->
        Logger.warning("Failed to initialize channel #{channel_id}: #{inspect(reason)}")
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
  def handle_call(:get_participants, _from, channel) do
    {:reply, {:ok, channel.participants}, channel}
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

  @spec participant_topic(String.t(), String.t()) :: String.t()
  defp participant_topic(channel_id, participant_id) do
    "channel:#{channel_id}:participant:#{participant_id}"
  end

  @spec has_participant?(t(), String.t()) :: boolean()
  defp has_participant?(channel, participant_id) do
    Enum.any?(channel.participants, &(&1.id == participant_id))
  end

  @spec create_message(String.t(), String.t()) :: Message.t()
  defp create_message(participant_id, content) do
    case Message.create(content, participant_id) do
      {:ok, message} -> message
      {:error, _reason} -> raise "Failed to create message"
    end
  end

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

  @spec via_tuple(String.t()) :: {:via, Registry, {atom(), String.t()}}
  defp via_tuple(channel_id) do
    {:via, Registry, {JidoChat.ChannelRegistry, channel_id}}
  end
end
