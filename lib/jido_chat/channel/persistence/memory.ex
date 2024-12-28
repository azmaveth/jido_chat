defmodule JidoChat.Channel.Persistence.Memory do
  @moduledoc """
  Agent-based in-memory persistence adapter for Channel state.
  Useful for testing and development environments.
  """
  @behaviour JidoChat.Channel.Persistence
  use Agent

  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @impl true
  def save(channel_id, channel_state) do
    Agent.update(__MODULE__, &Map.put(&1, channel_id, channel_state))
  end

  @impl true
  def load(channel_id) do
    case Agent.get(__MODULE__, &Map.get(&1, channel_id)) do
      nil -> {:error, :not_found}
      channel_state -> {:ok, channel_state}
    end
  end

  @impl true
  def delete(channel_id) do
    Agent.update(__MODULE__, &Map.delete(&1, channel_id))
  end
end
