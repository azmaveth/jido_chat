defmodule JidoChat.Channel.Strategy.RoundRobin do
  @moduledoc """
  A turn-based strategy that rotates between non-human participants (agents) in a round-robin fashion.

  This strategy implements the following rules:
  - Human participants can post messages at any time
  - Agent participants can only post during their assigned turn
  - Turns rotate sequentially through all agent participants
  - If there are no agents, no turns are assigned

  ## Usage

      # Create a channel with round robin strategy
      {:ok, channel} = JidoChat.Channel.new(strategy: JidoChat.Channel.Strategy.RoundRobin)

  ## Turn Management
  The strategy maintains a `current_turn` field in the channel state that tracks which agent
  can currently post. When advancing turns:

  1. If there are no agents, `current_turn` is set to nil
  2. Otherwise, the turn advances to the next agent in sequence
  3. After the last agent, it wraps back to the first agent
  """

  @behaviour JidoChat.Channel.Strategy

  @doc """
  Determines if a participant can post a message in the current channel state.

  ## Rules
  - Returns false if participant does not exist in channel
  - Human participants can always post (returns true)
  - For agents:
    - If no turn is assigned (nil), only the first agent can post
    - Otherwise, only the agent whose ID matches current_turn can post

  ## Parameters
    * `channel` - The channel struct containing participants and current turn
    * `participant_id` - ID of the participant attempting to post

  ## Returns
    * `boolean` - Whether the participant can post
  """
  @impl true
  @spec can_post?(JidoChat.Channel.t(), String.t()) ::
          {:ok, boolean()} | {:error, JidoChat.Channel.Strategy.strategy_error()}
  def can_post?(channel, participant_id) do
    case find_participant(channel, participant_id) do
      nil -> {:error, :invalid_participant}
      participant -> {:ok, can_participant_post?(channel, participant)}
    end
  end

  defp find_participant(channel, participant_id) do
    Enum.find(channel.participants, &(&1.id == participant_id))
  end

  defp can_participant_post?(channel, participant) do
    case participant.type do
      :human -> true
      :agent -> can_agent_post?(channel, participant)
    end
  end

  defp can_agent_post?(channel, agent) do
    if is_nil(channel.current_turn) do
      is_first_agent?(channel, agent)
    else
      channel.current_turn == agent.id
    end
  end

  defp is_first_agent?(channel, agent) do
    agents = Enum.filter(channel.participants, &(&1.type == :agent))
    first_agent = List.first(agents)
    if first_agent, do: first_agent.id == agent.id, else: false
  end

  @doc """
  Advances the turn to the next agent participant.

  Filters the channel participants to get only agents, then advances the turn
  to the next agent in sequence. If there are no agents, clears the current turn.

  ## Parameters
    * `channel` - The channel struct to update

  ## Returns
    * Updated channel struct with new current_turn value
  """
  @impl true
  @spec next_turn(JidoChat.Channel.t()) ::
          {:ok, JidoChat.Channel.t()} | {:error, JidoChat.Channel.Strategy.strategy_error()}
  def next_turn(%JidoChat.Channel{} = channel) do
    agents = Enum.filter(channel.participants, &(&1.type == :agent))

    case agents do
      [] ->
        {:ok, %JidoChat.Channel{channel | current_turn: nil}}

      [_single_agent] ->
        # If there's only one agent, they always get the turn
        {:ok, %JidoChat.Channel{channel | current_turn: List.first(agents).id}}

      agents ->
        current_index = get_current_index(agents, channel.current_turn)
        next_index = rem(current_index + 1, length(agents))
        next_agent = Enum.at(agents, next_index)
        {:ok, %JidoChat.Channel{channel | current_turn: next_agent.id}}
    end
  end

  # Gets the index of the current turn holder in the agents list.
  #
  # Parameters:
  #   * agents - List of agent participants
  #   * current_turn - ID of current turn holder or nil
  #
  # Returns:
  #   * -1 if current_turn is nil or agent not found
  #   * Index of the current turn holder in agents list
  defp get_current_index(agents, current_turn) do
    case current_turn do
      nil ->
        -1

      id ->
        Enum.find_index(agents, &(&1.id == id)) || -1
    end
  end

  @doc """
  Selects the next participant based on the previous message and available participants.

  This function implements the core turn selection logic:
  - Filters and sorts available agents
  - Determines the previous participant's position
  - Calculates the next participant in sequence
  - Handles edge cases like no agents or single agent

  ## Parameters
    * `participants` - Map of participant structs
    * `message` - Previous message struct containing participant_id

  ## Returns
    * `{:ok, participant_id}` - ID of the next participant
    * `{:error, :no_agents_available}` - When no agents are available
  """
  @spec next_participant(%{String.t() => JidoChat.Participant.t()}, JidoChat.Message.t()) ::
          {:ok, String.t()} | {:error, :no_agents_available}
  def next_participant(participants, message) do
    agents =
      Map.values(participants)
      |> Enum.filter(&(&1.type == :agent))
      |> Enum.sort_by(& &1.id)

    case agents do
      [] ->
        {:error, :no_agents_available}

      [agent] ->
        {:ok, agent.id}

      agents ->
        # Find the index of the last sender if it's an agent
        last_sender_index =
          case message.participant_id do
            nil -> -1
            id -> Enum.find_index(agents, &(&1.id == id))
          end

        next_index =
          case last_sender_index do
            nil -> 0
            -1 -> 0
            idx -> rem(idx + 1, length(agents))
          end

        next_agent = Enum.at(agents, next_index)
        {:ok, next_agent.id}
    end
  end
end
