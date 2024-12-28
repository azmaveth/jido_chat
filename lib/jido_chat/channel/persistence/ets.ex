defmodule JidoChat.Channel.Persistence.ETS do
  @moduledoc """
  Default ETS-based persistence implementation for Channel state
  """
  @behaviour JidoChat.Channel.Persistence
  use GenServer
  require Logger

  @table_name :jido_channels

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    table = :ets.new(@table_name, [:set, :public, :named_table])
    {:ok, %{table: table}}
  end

  @impl JidoChat.Channel.Persistence
  def save(channel_id, channel_state) do
    true = :ets.insert(@table_name, {channel_id, channel_state})
    :ok
  end

  @impl JidoChat.Channel.Persistence
  def load(channel_id) do
    case :ets.lookup(@table_name, channel_id) do
      [{^channel_id, channel_state}] -> {:ok, channel_state}
      [] -> {:error, :not_found}
    end
  end

  @impl JidoChat.Channel.Persistence
  def delete(channel_id) do
    true = :ets.delete(@table_name, channel_id)
    :ok
  end
end
