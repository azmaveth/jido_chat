defmodule JidoChat.Channel.Strategy.PubSubRoundRobin do
  @behaviour JidoChat.Channel.Strategy

  # Add module attribute to store the last selected agent
  @last_agent_key :pubsub_round_robin_last_agent

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
    agents =
      Map.values(participants)
      |> Enum.filter(&(&1.type == :agent))
      |> Enum.sort_by(& &1.id)

    case agents do
      [] ->
        {:error, :no_agents_available}

      [agent] ->
        Process.put(@last_agent_key, agent.id)
        {:ok, agent.id}

      agents ->
        last_agent = Process.get(@last_agent_key)

        last_agent_index =
          case last_agent do
            nil -> -1
            id -> Enum.find_index(agents, &(&1.id == id))
          end

        next_index =
          case last_agent_index do
            nil -> 0
            -1 -> 0
            idx -> rem(idx + 1, length(agents))
          end

        next_agent = Enum.at(agents, next_index)

        # Store the selected agent for the next round
        Process.put(@last_agent_key, next_agent.id)

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
