defmodule JidoChat.Channel.Strategy.PubSubRoundRobin do
  @behaviour JidoChat.Channel.Strategy

  @impl true
  def can_post?(_channel, _participant_id), do: true

  @impl true
  def next_turn(channel) do
    agents = get_agent_participants(channel)

    case agents do
      [] ->
        %{channel | current_turn: nil}

      _ ->
        current_index = get_current_index(agents, channel.current_turn)
        next_index = rem(current_index + 1, length(agents))
        next_agent = Enum.at(agents, next_index)

        %{channel | current_turn: next_agent.id}
    end
  end

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
        Logger.warn("No agents available to select from")
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

  defp get_agent_participants(channel) do
    channel.participants
    |> Enum.filter(&(&1.type == :agent))
    |> Enum.sort_by(& &1.id)
  end

  defp get_current_index(agents, current_turn) do
    case current_turn do
      nil -> -1
      id -> Enum.find_index(agents, &(&1.id == id)) || -1
    end
  end
end
