defmodule JidoChat.PubSub.MessageBroker do
  @moduledoc """
  Manages message broadcasting and participant subscriptions for chat channels.

  This module handles:
  - Message broadcasting to participants and channels
  - Participant registration and topic management
  - Turn-taking strategy coordination
  """

  use GenServer
  require Logger
  alias JidoChat.{Channel, Message, Participant}
  alias Phoenix.PubSub

  @type topic :: String.t()
  @type participant_id :: String.t()

  defmodule State do
    @moduledoc false
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
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Subscribes the broker to a topic.

  ## Parameters
    * `pid` - The MessageBroker process ID
    * `topic` - The topic string to subscribe to
  """
  @spec subscribe(pid(), topic()) :: :ok
  def subscribe(pid, topic) when is_binary(topic) do
    GenServer.call(pid, {:subscribe, topic})
  end

  @doc """
  Broadcasts a message to a topic.

  ## Parameters
    * `pid` - The MessageBroker process ID
    * `topic` - The topic to broadcast to
    * `message` - The message to broadcast
  """
  @spec broadcast(pid(), topic(), Message.t()) :: :ok
  def broadcast(pid, topic, message) do
    GenServer.cast(pid, {:broadcast, topic, message})
  end

  @doc """
  Registers a participant with the broker and subscribes them to a topic.

  ## Parameters
    * `pid` - The MessageBroker process ID
    * `participant` - The participant struct to register
    * `topic` - The topic to subscribe the participant to
  """
  @spec register_participant(pid(), Participant.t(), topic()) :: :ok
  def register_participant(pid, participant = %Participant{}, topic) do
    GenServer.call(pid, {:register_participant, participant, topic})
  end

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

  @impl true
  @spec handle_call({:subscribe, topic()}, GenServer.from(), State.t()) ::
          {:reply, :ok, State.t()}
  def handle_call({:subscribe, topic}, _from, state) do
    :ok = PubSub.subscribe(JidoChat.PubSub, topic)
    {:reply, :ok, state}
  end

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

  @spec handle_cast({:broadcast, topic(), Message.t()}, State.t()) :: {:noreply, State.t()}
  @impl true
  def handle_cast({:broadcast, topic, message}, state) do
    channel_topic = "channel:#{state.channel_id}"
    :ok = PubSub.broadcast(JidoChat.PubSub, channel_topic, {:message, message})

    if topic != channel_topic do
      :ok = PubSub.broadcast(JidoChat.PubSub, topic, {:message, message})

      if Map.get(state.participants, message.participant_id, %{type: nil}).type == :agent do
        case state.strategy.next_participant(state.participants, message) do
          {:ok, next_participant_id} when next_participant_id != message.participant_id ->
            if participant_topic = Map.get(state.topic_registry, next_participant_id) do
              :ok =
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
    end

    {:noreply, state}
  end

  @impl true
  @spec handle_info({:message, Message.t()}, State.t()) :: {:noreply, State.t()}
  def handle_info({:message, message}, state) do
    # Handle incoming messages from subscribed topics
    channel_topic = "channel:#{state.channel_id}"
    PubSub.broadcast(JidoChat.PubSub, channel_topic, {:message, message})
    {:noreply, state}
  end
end
