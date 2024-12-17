defmodule JidoChat.Room.Persistence.Memory do
  @moduledoc """
  Agent-based in-memory persistence adapter for Room state.
  Useful for testing and development environments.
  """
  @behaviour JidoChat.Room.Persistence
  use Agent

  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @impl true
  def save(room_id, room_state) do
    Agent.update(__MODULE__, &Map.put(&1, room_id, room_state))
  end

  @impl true
  def load(room_id) do
    case Agent.get(__MODULE__, &Map.get(&1, room_id)) do
      nil -> {:error, :not_found}
      room_state -> {:ok, room_state}
    end
  end

  @impl true
  def delete(room_id) do
    Agent.update(__MODULE__, &Map.delete(&1, room_id))
  end
end
