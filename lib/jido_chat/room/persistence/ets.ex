defmodule JidoChat.Room.Persistence.ETS do
  @moduledoc """
  Default ETS-based persistence implementation for Room state
  """
  @behaviour JidoChat.Room.Persistence
  use GenServer
  require Logger

  @table_name :jido_rooms

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    table = :ets.new(@table_name, [:set, :public, :named_table])
    {:ok, %{table: table}}
  end

  @impl JidoChat.Room.Persistence
  def save(room_id, room_state) do
    true = :ets.insert(@table_name, {room_id, room_state})
    :ok
  end

  @impl JidoChat.Room.Persistence
  def load(room_id) do
    case :ets.lookup(@table_name, room_id) do
      [{^room_id, room_state}] -> {:ok, room_state}
      [] -> {:error, :not_found}
    end
  end

  @impl JidoChat.Room.Persistence
  def delete(room_id) do
    true = :ets.delete(@table_name, room_id)
    :ok
  end
end
