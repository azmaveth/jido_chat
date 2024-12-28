defmodule JidoChat.Channel.Persistence.ETS do
  @moduledoc """
  Default ETS-based persistence implementation for Channel state.

  This module provides an ETS-backed storage adapter implementing the `JidoChat.Channel.Persistence`
  behaviour. It uses a public ETS table to store channel state, allowing fast concurrent access
  while maintaining persistence within the runtime of the application.

  ## Features
  - Fast in-memory storage using ETS
  - Concurrent read/write access via public table
  - Process-independent persistence (survives process crashes)
  - Simple key-value storage model

  ## Usage
      # Start the persistence service
      {:ok, _pid} = JidoChat.Channel.Persistence.ETS.start_link()

      # Save channel state
      :ok = JidoChat.Channel.Persistence.ETS.save("channel-123", channel)

      # Load channel state
      {:ok, channel} = JidoChat.Channel.Persistence.ETS.load("channel-123")

  ## Limitations
  - Data persists only during runtime (cleared on application restart)
  - No built-in backup/restore functionality
  - Limited by available memory
  """

  @behaviour JidoChat.Channel.Persistence
  use GenServer
  require Logger

  @table_name :jido_channels

  @doc """
  Starts the ETS persistence service.

  Creates a named public ETS table for storing channel state.

  ## Parameters
    * `opts` - Keyword list of options (currently unused)

  ## Returns
    * `{:ok, pid}` - On successful start
    * `{:error, reason}` - If start fails
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc false
  @impl true
  def init(_opts) do
    Logger.info("Starting ETS persistence service")
    table = :ets.new(@table_name, [:set, :public, :named_table])
    {:ok, %{table: table}}
  end

  @doc """
  Saves channel state to ETS storage.

  ## Parameters
    * `channel_id` - Unique identifier for the channel
    * `channel_state` - Complete channel state to persist

  ## Returns
    * `:ok` - On successful save
    * raises on ETS write failure
  """
  @impl JidoChat.Channel.Persistence
  @spec save(String.t(), JidoChat.Channel.t()) :: :ok
  def save(channel_id, channel_state) do
    Logger.debug("Saving channel state: #{channel_id}")
    true = :ets.insert(@table_name, {channel_id, channel_state})
    :ok
  end

  @doc """
  Loads channel state from ETS storage.

  ## Parameters
    * `channel_id` - Unique identifier for the channel to load

  ## Returns
    * `{:ok, channel}` - Successfully loaded channel state
    * `{:error, :not_found}` - If channel does not exist
  """
  @impl JidoChat.Channel.Persistence
  @spec load(String.t()) :: {:ok, JidoChat.Channel.t()} | {:error, :not_found}
  def load(channel_id) do
    Logger.debug("Loading channel state: #{channel_id}")

    case :ets.lookup(@table_name, channel_id) do
      [{^channel_id, channel_state}] -> {:ok, channel_state}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Deletes channel state from ETS storage.

  ## Parameters
    * `channel_id` - Unique identifier for the channel to delete

  ## Returns
    * `:ok` - On successful deletion
    * raises on ETS delete failure
  """
  @impl JidoChat.Channel.Persistence
  @spec delete(String.t()) :: :ok
  def delete(channel_id) do
    Logger.debug("Deleting channel state: #{channel_id}")
    true = :ets.delete(@table_name, channel_id)
    :ok
  end
end
