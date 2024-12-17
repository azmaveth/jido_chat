defmodule JidoChat.Room do
  use GenServer
  require Logger
  use Jido.Util, debug_enabled: false

  @default_message_limit 1000

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          participants: [JidoChat.Participant.t()],
          messages: [JidoChat.Message.t()],
          turn_strategy: module(),
          current_turn: String.t() | nil,
          message_limit: non_neg_integer(),
          metadata: map()
        }

  defstruct [
    :id,
    :name,
    participants: [],
    messages: [],
    turn_strategy: JidoChat.Room.Strategy.FreeForm,
    current_turn: nil,
    metadata: %{},
    message_limit: @default_message_limit
  ]

  # Client API
  def start_link(room_id, opts \\ []) do
    strategy = Keyword.get(opts, :strategy, JidoChat.Room.Strategy.FreeForm)
    message_limit = Keyword.get(opts, :message_limit)
    GenServer.start_link(__MODULE__, {room_id, strategy, message_limit}, opts)
  end

  def post_message(pid, participant_id, content) do
    GenServer.call(pid, {:post_message, participant_id, content})
  end

  def join(pid, participant) do
    GenServer.call(pid, {:join, participant})
  end

  def leave(pid, participant_id) do
    GenServer.call(pid, {:leave, participant_id})
  end

  @doc """
  Gets messages from the room.

  ## Options

    * `:order` - Either `:chronological` (oldest first) or `:reverse_chronological` (newest first).
      Defaults to `:chronological`.

  ## Examples

      # Get messages in chronological order (oldest first)
      {:ok, messages} = Room.get_messages(pid)

      # Get messages in reverse chronological order (newest first)
      {:ok, messages} = Room.get_messages(pid, order: :reverse_chronological)
  """
  def get_messages(pid, opts \\ []) do
    order = Keyword.get(opts, :order, :chronological)
    GenServer.call(pid, {:get_messages, order})
  end

  def get_participants(pid) do
    GenServer.call(pid, :get_participants)
  end

  # Server Callbacks
  @impl true
  def init({room_id, strategy, message_limit}) do
    case JidoChat.Room.Persistence.load_or_create(room_id) do
      {:ok, room} ->
        room = %{
          room
          | turn_strategy: strategy,
            # Ensure current_turn is reset
            current_turn: nil,
            message_limit: message_limit
        }

        {:ok, room}

      {:error, reason} ->
        Logger.warning("Failed to initialize room #{room_id}: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:post_message, participant_id, content}, _from, room) do
    debug("""
    Attempting to post message:
    Participant: #{participant_id}
    Room state: #{inspect(room, pretty: true)}
    """)

    with true <- has_participant?(room, participant_id),
         true <- room.turn_strategy.can_post?(room, participant_id) do
      message = create_message(participant_id, content)
      updated_room = add_message_to_room(room, message)
      updated_room = room.turn_strategy.next_turn(updated_room)

      # Save the updated room state
      :ok = JidoChat.Room.Persistence.save(room.id, updated_room)

      debug("""
      Message posted successfully:
      Updated room state: #{inspect(updated_room, pretty: true)}
      """)

      {:reply, {:ok, message}, updated_room}
    else
      false ->
        debug("Post message failed: not allowed")
        {:reply, {:error, :not_allowed}, room}
    end
  end

  @impl true
  def handle_call({:join, participant}, _from, room) do
    debug("""
    Participant joining:
    Participant: #{inspect(participant)}
    Current participants: #{inspect(room.participants)}
    """)

    if has_participant?(room, participant.id) do
      debug("Join failed: already joined")
      {:reply, {:error, :already_joined}, room}
    else
      updated_room = %{room | participants: [participant | room.participants]}
      :ok = JidoChat.Room.Persistence.save(room.id, updated_room)
      debug("Join successful. Updated participants: #{inspect(updated_room.participants)}")
      {:reply, :ok, updated_room}
    end
  end

  @impl true
  def handle_call({:leave, participant_id}, _from, room) do
    updated_participants = Enum.reject(room.participants, &(&1.id == participant_id))
    updated_room = %{room | participants: updated_participants}
    :ok = JidoChat.Room.Persistence.save(room.id, updated_room)
    {:reply, :ok, updated_room}
  end

  @impl true
  def handle_call({:get_messages, order}, _from, room) do
    messages =
      case order do
        # oldest first
        :chronological -> Enum.reverse(room.messages)
        # newest first
        :reverse_chronological -> room.messages
      end

    {:reply, {:ok, messages}, room}
  end

  @impl true
  def handle_call(:get_participants, _from, room) do
    {:reply, {:ok, room.participants}, room}
  end

  # Private Functions
  defp has_participant?(room, participant_id) do
    Enum.any?(room.participants, &(&1.id == participant_id))
  end

  defp create_message(participant_id, content) do
    %JidoChat.Message{
      id: UUID.uuid4(),
      content: content,
      participant_id: participant_id,
      timestamp: DateTime.utc_now(),
      metadata: %{}
    }
  end

  defp add_message_to_room(room, message) do
    updated_messages = [message | room.messages]

    case room.message_limit do
      nil ->
        %{room | messages: updated_messages}

      limit when is_integer(limit) and limit > 0 ->
        %{room | messages: Enum.take(updated_messages, limit)}
    end
  end
end
