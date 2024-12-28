defmodule JidoChat.PubSub.MessageBroker do
  @moduledoc """
  Manages message broadcasting and participant subscriptions for chat channels.

  This module provides a centralized message broker for managing pub/sub communication
  between participants in a chat channel. It handles message broadcasting, participant
  registration, topic management, and coordinates with turn-taking strategies.

  ## Responsibilities

  - Message broadcasting to participants and channels
  - Participant registration and topic management
  - Turn-taking strategy coordination
  - Topic subscription management
  - Message routing and delivery

  ## Usage

      # Start a new message broker for a channel
      {:ok, broker} = MessageBroker.start_link(channel_id: "channel-123")

      # Register a participant
      :ok = MessageBroker.register_participant(broker, participant, "user:123")

      # Subscribe to a topic
      :ok = MessageBroker.subscribe(broker, "channel:123")

      # Broadcast a message
      :ok = MessageBroker.broadcast(broker, "channel:123", message)

  ## Topics

  The broker manages several types of topics:

  - Channel topics: "channel:{channel_id}"
  - Participant topics: "user:{user_id}"
  - Custom topics: Any string topic name

  Messages are broadcast to both the channel topic and participant-specific topics
  to enable targeted delivery.

  ## Turn Management

  For agent participants, the broker coordinates with the channel's turn-taking strategy
  to manage conversation flow:

  1. When an agent sends a message, the broker consults the strategy
  2. The strategy determines the next participant
  3. The broker sends a turn notification to the next participant
  """

  use GenServer
  require Logger
  alias JidoChat.{Message, Participant}
  alias Phoenix.PubSub

  @type topic :: String.t()
  @type participant_id :: String.t()

  defmodule State do
    @moduledoc """
    Internal state for the MessageBroker.

    Tracks:
    - Channel ID and turn-taking strategy
    - Registered participants
    - Topic subscriptions per participant
    """

    alias JidoChat.PubSub.MessageBroker

    @type t :: %__MODULE__{
            channel_id: String.t(),
            strategy: module(),
            participants: %{MessageBroker.participant_id() => Participant.t()},
            topic_registry: %{MessageBroker.participant_id() => MessageBroker.topic()}
          }
    defstruct [:channel_id, :strategy, participants: %{}, topic_registry: %{}]
  end

  @doc """
  Starts a new MessageBroker process linked to the current process.

  ## Options

    * `:channel_id` - Required. The ID of the channel this broker manages
    * `:strategy` - Optional. The turn-taking strategy module to use. Defaults to RoundRobin

  ## Returns

    * `{:ok, pid}` - The broker process ID on success
    * `{:error, reason}` - On failure

  ## Examples

      iex> MessageBroker.start_link(channel_id: "channel-123")
      {:ok, #PID<0.123.0>}
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Subscribes the broker to a topic.

  The broker will receive all messages broadcast to this topic and can
  rebroadcast them to other subscribers.

  ## Parameters

    * `pid` - The MessageBroker process ID
    * `topic` - The topic string to subscribe to

  ## Returns

    * `:ok` - On successful subscription

  ## Examples

      iex> MessageBroker.subscribe(broker, "channel:123")
      :ok
  """
  @spec subscribe(pid(), topic()) :: :ok
  def subscribe(pid, topic) when is_binary(topic) do
    GenServer.call(pid, {:subscribe, topic})
  end

  @doc """
  Broadcasts a message to a topic.

  The message will be delivered to all subscribers of the topic, including
  the channel's main topic.

  ## Parameters

    * `pid` - The MessageBroker process ID
    * `topic` - The topic to broadcast to
    * `message` - The message to broadcast

  ## Returns

    * `:ok` - Message was broadcast successfully

  ## Examples

      iex> MessageBroker.broadcast(broker, "channel:123", message)
      :ok
  """
  @spec broadcast(pid(), topic(), Message.t()) :: :ok
  def broadcast(pid, topic, message) do
    GenServer.cast(pid, {:broadcast, topic, message})
  end

  @doc """
  Registers a participant with the broker and subscribes them to a topic.

  This associates a participant with their dedicated topic and enables
  the broker to route messages appropriately.

  ## Parameters

    * `pid` - The MessageBroker process ID
    * `participant` - The participant struct to register
    * `topic` - The topic to subscribe the participant to

  ## Returns

    * `:ok` - Participant was registered successfully

  ## Examples

      iex> MessageBroker.register_participant(broker, participant, "user:123")
      :ok
  """
  @spec register_participant(pid(), Participant.t(), topic()) :: :ok
  def register_participant(pid, %Participant{} = participant, topic) do
    GenServer.call(pid, {:register_participant, participant, topic})
  end

  # GenServer Implementation

  # Initializes the broker state with the given channel ID and strategy.
  # Creates an empty state with no participants or topic registrations.
  @impl true
  @spec init(keyword()) :: {:ok, State.t()}
  def init(opts) do
    channel_id = Keyword.fetch!(opts, :channel_id)
    strategy = Keyword.get(opts, :strategy, JidoChat.Channel.Strategy.RoundRobin)

    state = %State{
      channel_id: channel_id,
      strategy: strategy,
      participants: %{},
      topic_registry: %{}
    }

    {:ok, state}
  end

  # Handles topic subscription requests by subscribing to the Phoenix PubSub system.
  @impl true
  @spec handle_call({:subscribe, topic()}, GenServer.from(), State.t()) ::
          {:reply, :ok, State.t()}
  def handle_call({:subscribe, topic}, _from, state) do
    :ok = PubSub.subscribe(JidoChat.PubSub, topic)
    {:reply, :ok, state}
  end

  # Registers a new participant and their associated topic.
  # Updates the state to track the participant and subscribes to their topic.
  @impl true
  @spec handle_call(
          {:register_participant, Participant.t(), topic()},
          GenServer.from(),
          State.t()
        ) ::
          {:reply, :ok, State.t()}
  def handle_call({:register_participant, participant, topic}, _from, state) do
    updated_participants = Map.put(state.participants, participant.id, participant)
    updated_registry = Map.put(state.topic_registry, participant.id, topic)

    updated_state = %{
      state
      | participants: updated_participants,
        topic_registry: updated_registry
    }

    # Subscribe to participant's topic
    :ok = PubSub.subscribe(JidoChat.PubSub, topic)

    {:reply, :ok, updated_state}
  end

  # Handles message broadcasting by:
  # 1. Broadcasting to the channel topic
  # 2. Broadcasting to the specific participant topic
  # 3. Managing turn notifications for agent participants
  @impl true
  @spec handle_cast({:broadcast, topic(), Message.t()}, State.t()) :: {:noreply, State.t()}
  def handle_cast({:broadcast, topic, message}, state) do
    broadcast_message(topic, message, state)
    {:noreply, state}
  end

  # Private helper functions

  defp broadcast_message(topic, message, state) do
    channel_topic = "channel:#{state.channel_id}"
    :ok = PubSub.broadcast(JidoChat.PubSub, channel_topic, {:message, message})

    broadcast_to_participant_topic(topic, channel_topic, message, state)
  end

  defp broadcast_to_participant_topic(topic, channel_topic, message, state) do
    if topic == channel_topic do
      :ok
    else
      :ok = PubSub.broadcast(JidoChat.PubSub, topic, {:message, message})
      handle_agent_turn(message, state)
    end
  end

  defp handle_agent_turn(message, state) do
    participant = Map.get(state.participants, message.participant_id, %{type: nil})

    if participant.type == :agent do
      notify_next_participant(message, state)
    end
  end

  defp notify_next_participant(message, state) do
    case state.strategy.next_participant(state.participants, message) do
      {:ok, next_participant_id} when next_participant_id != message.participant_id ->
        participant_topic = Map.get(state.topic_registry, next_participant_id)

        if participant_topic do
          PubSub.broadcast(
            JidoChat.PubSub,
            participant_topic,
            {:turn_notification, next_participant_id}
          )
        end

      _ ->
        :ok
    end
  end

  # Handles incoming messages from subscribed topics by rebroadcasting them
  # to the channel topic to ensure all participants receive the message.
  @impl true
  @spec handle_info({:message, Message.t()}, State.t()) :: {:noreply, State.t()}
  def handle_info({:message, message}, state) do
    channel_topic = "channel:#{state.channel_id}"
    PubSub.broadcast(JidoChat.PubSub, channel_topic, {:message, message})
    {:noreply, state}
  end
end
