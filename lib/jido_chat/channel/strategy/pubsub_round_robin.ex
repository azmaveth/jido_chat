defmodule JidoChat.Channel.Strategy.PubSubRoundRobin do
  @moduledoc """
  A turn-based strategy that implements round-robin turn management for agent participants with pub/sub capabilities.

  This strategy extends the basic round-robin approach by adding pub/sub functionality, allowing for:
  - Dynamic participant management through pub/sub events
  - Deterministic turn order based on agent IDs
  - Automatic turn advancement
  - Detailed logging of turn transitions

  ## Usage

      # Create a channel with pubsub round robin strategy
      {:ok, channel} = JidoChat.Channel.new(strategy: JidoChat.Channel.Strategy.PubSubRoundRobin)

  ## Turn Management
  The strategy maintains turn state through:
  - `current_turn` field tracking the current agent's ID
  - Sorted list of agents by ID for consistent ordering
  - Automatic wrapping to first agent after last agent's turn

  ## Logging
  The module includes comprehensive debug logging to track:
  - Participant selection decisions
  - Turn transitions
  - Agent availability
  - Error conditions
  """

  @behaviour JidoChat.Channel.Strategy

  @doc """
  Determines if a participant can post a message.

  Currently allows all participants to post messages. This may be restricted
  in future versions to implement turn enforcement.

  ## Parameters
    * `_channel` - The channel struct (unused)
    * `_participant_id` - ID of participant attempting to post (unused)

  ## Returns
    * `{:ok, true}` - Currently always allows posting
  """
  @impl true
  @spec can_post?(JidoChat.Channel.t(), String.t()) ::
          {:ok, boolean()} | {:error, JidoChat.Channel.Strategy.strategy_error()}
  def can_post?(channel, participant_id) do
    case Enum.find(channel.participants, &(&1.id == participant_id)) do
      nil ->
        {:error, :invalid_participant}

      %{type: :human} ->
        {:ok, true}

      %{type: :agent} = agent ->
        agents = get_agent_participants(channel)

        cond do
          # No agents, allow posting
          Enum.empty?(agents) ->
            {:ok, true}

          # No turn set, only first agent can post
          is_nil(channel.current_turn) ->
            first_agent = List.first(agents)
            {:ok, first_agent.id == agent.id}

          # Current turn can post
          channel.current_turn == agent.id ->
            {:ok, true}

          # Next agent in sequence can post if current turn has posted
          true ->
            current_index = get_current_index(agents, channel.current_turn)
            next_index = rem(current_index + 1, length(agents))
            next_agent = Enum.at(agents, next_index)

            # Only allow next agent if current turn has posted
            {:ok, agent.id == next_agent.id && has_current_turn_posted?(channel)}
        end
    end
  end

  # Helper to check if current turn has posted
  defp has_current_turn_posted?(channel) do
    case channel.messages do
      [] -> false
      [last_message | _] -> last_message.participant_id == channel.current_turn
    end
  end

  @doc """
  Advances the turn to the next agent participant.

  Calculates the next turn based on the current turn and available agents.
  Maintains a consistent order by sorting agents by ID.

  ## Parameters
    * `channel` - The channel struct containing participants and current turn

  ## Returns
    * `{:ok, updated_channel}` - Updated channel struct with new current_turn value
    * `{:error, reason}` - If there was an error transitioning turns

  ## Examples
      iex> channel = %Channel{participants: [%{id: "agent1", type: :agent}, %{id: "agent2", type: :agent}], current_turn: "agent1"}
      iex> next_turn(channel)
      {:ok, %Channel{current_turn: "agent2", ...}}
  """
  @impl true
  @spec next_turn(JidoChat.Channel.t()) ::
          {:ok, JidoChat.Channel.t()} | {:error, JidoChat.Channel.Strategy.strategy_error()}
  def next_turn(channel) do
    agents = get_agent_participants(channel)

    case agents do
      [] ->
        {:ok, %{channel | current_turn: nil}}

      _ ->
        current_index = get_current_index(agents, channel.current_turn)
        next_index = rem(current_index + 1, length(agents))
        next_agent = Enum.at(agents, next_index)

        {:ok, %{channel | current_turn: next_agent.id}}
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

  ## Examples
      iex> participants = %{"agent1" => %{id: "agent1", type: :agent}}
      iex> message = %{participant_id: nil}
      iex> next_participant(participants, message)
      {:ok, "agent1"}
  """
  def next_participant(participants, message) do
    require Logger
    Logger.debug("Selecting next participant from #{inspect(participants)}")
    Logger.debug("Previous message: #{inspect(message)}")

    agents =
      Map.values(participants)
      |> Enum.filter(&(&1.type == :agent))
      |> Enum.sort_by(& &1.id)

    Logger.debug("Available agents: #{inspect(agents)}")

    case agents do
      [] ->
        Logger.warning("No agents available to select from")
        {:error, :no_agents_available}

      [agent] ->
        Logger.debug("Only one agent available, selecting #{agent.id}")
        {:ok, agent.id}

      agents ->
        # Find the index of the last sender if it's an agent
        last_sender_index =
          case message.participant_id do
            nil ->
              Logger.debug("No previous participant ID")
              -1

            id ->
              idx = Enum.find_index(agents, &(&1.id == id))
              Logger.debug("Previous participant #{id} was at index #{idx}")
              idx
          end

        next_index =
          case last_sender_index do
            nil ->
              Logger.debug("No last sender found, starting at 0")
              0

            -1 ->
              Logger.debug("Invalid last sender index, starting at 0")
              0

            idx ->
              next = rem(idx + 1, length(agents))
              Logger.debug("Moving from index #{idx} to #{next}")
              next
          end

        next_agent = Enum.at(agents, next_index)
        Logger.debug("Selected next agent: #{next_agent.id}")
        {:ok, next_agent.id}
    end
  end

  # Filters and sorts agent participants from the channel.
  #
  # Parameters:
  #   * channel - Channel struct containing participants
  #
  # Returns:
  #   * List of agent participants sorted by ID
  defp get_agent_participants(channel) do
    channel.participants
    |> Enum.filter(&(&1.type == :agent))
    |> Enum.sort_by(& &1.id)
  end

  # Gets the current agent's index in the sorted agent list.
  #
  # Parameters:
  #   * agents - Sorted list of agent participants
  #   * current_turn - ID of current turn holder
  #
  # Returns:
  #   * Integer index of current agent, or -1 if not found
  defp get_current_index(agents, current_turn) do
    case current_turn do
      nil -> -1
      id -> Enum.find_index(agents, &(&1.id == id)) || -1
    end
  end
end
