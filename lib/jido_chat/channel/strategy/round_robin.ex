defmodule JidoChat.Channel.Strategy.RoundRobin do
  @moduledoc """
  A turn-based strategy that rotates between non-human participants
  """
  @behaviour JidoChat.Channel.Strategy

  @impl true
  def can_post?(channel, participant_id) do
    participant = Enum.find(channel.participants, &(&1.id == participant_id))

    cond do
      is_nil(participant) ->
        false

      participant.type == :human ->
        true

      is_nil(channel.current_turn) ->
        agents =
          Enum.filter(channel.participants, &(&1.type == :agent))
          |> Enum.reverse()

        first_agent = List.first(agents)

        first_agent && first_agent.id == participant_id

      true ->
        channel.current_turn == participant_id
    end
  end

  @impl true
  def next_turn(channel) do
    agents =
      Enum.filter(channel.participants, &(&1.type == :agent))
      |> Enum.reverse()

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

  defp get_current_index(agents, current_turn) do
    case current_turn do
      nil ->
        -1

      id ->
        Enum.find_index(agents, &(&1.id == id)) || -1
    end
  end
end
