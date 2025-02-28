defmodule Jido.Chat.Room.Strategy do
  @moduledoc """
  Defines the behaviour for turn-based messaging strategies in chat rooms.

  Strategies control whose turn it is to speak in a chat room, which can be
  useful for coordinating conversations between humans and agents.
  """

  alias Jido.Chat.Message
  alias Jido.Chat.Participant

  @doc """
  Returns the appropriate strategy module based on the strategy type.

  ## Parameters

  - `strategy` - Either an atom (:free_form, :round_robin) or a strategy struct

  ## Returns

  - A strategy struct
  """
  def get_strategy(strategy) when is_atom(strategy) do
    case strategy do
      :round_robin ->
        {:ok, strategy_state} = Jido.Chat.Room.Strategy.RoundRobin.init(%{room_id: "temp", participants: %{}})
        Map.put(strategy_state, :__struct__, Jido.Chat.Room.Strategy.RoundRobin)
      :free_form ->
        {:ok, strategy_state} = Jido.Chat.Room.Strategy.FreeForm.init(%{room_id: "temp", participants: %{}})
        Map.put(strategy_state, :__struct__, Jido.Chat.Room.Strategy.FreeForm)
      _ ->
        {:ok, strategy_state} = Jido.Chat.Room.Strategy.FreeForm.init(%{room_id: "temp", participants: %{}})
        Map.put(strategy_state, :__struct__, Jido.Chat.Room.Strategy.FreeForm)
    end
  end

  def get_strategy(%{} = strategy), do: strategy

  @doc """
  Adds a participant to the strategy state.

  ## Parameters

  - `strategy` - The strategy struct
  - `participants` - The current participants map
  - `participant` - The participant to add

  ## Returns

  - `{updated_strategy, updated_participants}` - The updated strategy and participants
  """
  def add_participant(strategy, participants, participant) do
    {:ok, updated_strategy} = strategy.__struct__.handle_participant_added(strategy, participant)
    updated_participants = Map.put(participants, participant.id, participant)
    {updated_strategy, updated_participants}
  end

  @doc """
  Removes a participant from the strategy state.

  ## Parameters

  - `strategy` - The strategy struct
  - `participants` - The current participants map
  - `participant_id` - The ID of the participant to remove

  ## Returns

  - `{updated_strategy, updated_participants}` - The updated strategy and participants
  """
  def remove_participant(strategy, participants, participant_id) do
    {:ok, updated_strategy} = strategy.__struct__.handle_participant_removed(strategy, participant_id)
    updated_participants = Map.delete(participants, participant_id)
    {updated_strategy, updated_participants}
  end

  @doc """
  Checks if a message is allowed based on the strategy rules.

  ## Parameters

  - `strategy` - The strategy struct
  - `participants` - The current participants map
  - `message` - The message to check

  ## Returns

  - `{:ok, notifications}` or `{:error, reason, notifications}` - Result and any notifications
  """
  def is_message_allowed(strategy, participants, message) do
    participant = Map.get(participants, message.sender)

    if participant do
      case strategy.__struct__.is_message_allowed(strategy, message) do
        {:ok, allowed, _updated_strategy} ->
          if allowed do
            {:ok, []}
          else
            {:error, :not_participants_turn, []}
          end

        {:ok, allowed, _updated_strategy, notifications} ->
          if allowed do
            {:ok, notifications}
          else
            {:error, :not_participants_turn, notifications}
          end
      end
    else
      {:error, :sender_not_in_room, []}
    end
  end

  @doc """
  Processes a message according to the strategy rules.

  ## Parameters

  - `strategy` - The strategy struct
  - `participants` - The current participants map
  - `message` - The message to process
  - `room_id` - The ID of the room

  ## Returns

  - `{updated_strategy, notifications}` - The updated strategy and any notifications
  """
  def process_message(strategy, participants, message, room_id) do
    {:ok, updated_strategy, notifications} = strategy.__struct__.advance_turn(strategy, :message_processed)

    # Convert notification participant IDs to actual notification messages
    notification_messages = Enum.map(notifications, fn participant_id ->
      case create_turn_notification(room_id, participant_id) do
        {:ok, notification} -> notification
        _ -> nil
      end
    end)
    |> Enum.filter(&(&1 != nil))

    {updated_strategy, notification_messages}
  end

  @doc """
  Creates a turn notification message.

  ## Parameters

  - `room_id` - The ID of the room
  - `participant_id` - The ID of the participant whose turn it is

  ## Returns

  - `{:ok, notification}` - The turn notification message
  """
  def create_turn_notification(room_id, participant_id) do
    # Ensure participant_id is a string
    participant_id_str = if is_struct(participant_id), do: inspect(participant_id), else: to_string(participant_id)

    content = "It's #{participant_id_str}'s turn to speak"

    Message.new(%{
      type: Message.type(:turn_notification),
      room_id: room_id,
      sender: "system",
      content: content,
      timestamp: DateTime.utc_now(),
      metadata: %{
        participant_id: participant_id_str
      }
    })
  end

  @doc """
  Initializes a new strategy state.

  ## Parameters

  - `opts` - A map of options including:
    - `:room_id` - The ID of the room
    - `:participants` - A map of participants in the room
    - `:turn_timeout` - Optional timeout in milliseconds for a participant's turn

  ## Returns

  - `{:ok, state}` - The initialized strategy state
  """
  @callback init(opts :: map()) :: {:ok, map()}

  @doc """
  Handles a participant being added to the room.

  ## Parameters

  - `state` - The current strategy state
  - `participant` - The participant being added

  ## Returns

  - `{:ok, new_state}` - The updated strategy state
  """
  @callback handle_participant_added(state :: map(), participant :: Participant.t()) ::
    {:ok, map()}

  @doc """
  Handles a participant being removed from the room.

  ## Parameters

  - `state` - The current strategy state
  - `participant_id` - The ID of the participant being removed

  ## Returns

  - `{:ok, new_state}` - The updated strategy state
  """
  @callback handle_participant_removed(state :: map(), participant_id :: String.t()) ::
    {:ok, map()}

  @doc """
  Checks if a message is allowed based on the strategy rules.

  ## Parameters

  - `state` - The current strategy state
  - `message` - The message to check

  ## Returns

  - `{:ok, allowed, new_state}` - Whether the message is allowed and the updated state
  - `{:ok, allowed, new_state, notifications}` - With additional notifications
  """
  @callback is_message_allowed(state :: map(), message :: Message.t()) ::
    {:ok, boolean(), map()} | {:ok, boolean(), map(), list()}

  @doc """
  Advances the turn to the next participant.

  ## Parameters

  - `state` - The current strategy state
  - `reason` - The reason for advancing the turn (:message_processed, :timeout, etc.)

  ## Returns

  - `{:ok, new_state, notifications}` - The updated state and any notifications
  """
  @callback advance_turn(state :: map(), reason :: atom()) ::
    {:ok, map(), list()}
end
