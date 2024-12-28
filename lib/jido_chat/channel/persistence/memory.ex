defmodule JidoChat.Channel.Persistence.Memory do
  @moduledoc """
  Agent-based in-memory persistence adapter for Channel state.

  This module provides a simple in-memory storage implementation using Elixir's Agent, making it
  ideal for testing and development environments. It implements the `JidoChat.Channel.Persistence`
  behaviour to provide consistent storage operations.

  ## Features
  - Process-based storage using Agents
  - Simple key-value storage model
  - Fast in-memory access
  - No persistence between restarts

  ## Usage
      # Start the persistence service
      {:ok, _pid} = JidoChat.Channel.Persistence.Memory.start_link()

      # Save channel state
      :ok = JidoChat.Channel.Persistence.Memory.save("channel-123", channel)

      # Load channel state
      {:ok, channel} = JidoChat.Channel.Persistence.Memory.load("channel-123")

  ## Limitations
  - Data is lost on process/application restart
  - Limited by available process memory
  - No concurrent access optimizations
  - Not suitable for production use
  """

  @behaviour JidoChat.Channel.Persistence
  use Agent

  @doc """
  Starts a new Agent process for storing channel state.

  The Agent is registered under this module's name and initialized with an empty map.

  ## Parameters
    * `opts` - Keyword list of options (currently unused)

  ## Returns
    * `{:ok, pid}` - On successful start
    * `{:error, reason}` - If start fails
  """
  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc """
  Saves channel state to the in-memory store.

  Updates the Agent's state by associating the channel_id with the provided channel state.

  ## Parameters
    * `channel_id` - Unique identifier for the channel
    * `channel_state` - Complete channel state to persist

  ## Returns
    * `:ok` - On successful save
  """
  @impl true
  @spec save(String.t(), JidoChat.Channel.t()) :: :ok
  def save(channel_id, channel_state) do
    Agent.update(__MODULE__, &Map.put(&1, channel_id, channel_state))
  end

  @doc """
  Loads channel state from the in-memory store.

  Retrieves the channel state associated with the given channel_id from the Agent's state.

  ## Parameters
    * `channel_id` - Unique identifier for the channel to load

  ## Returns
    * `{:ok, channel}` - When channel is found
    * `{:error, :not_found}` - When channel does not exist
  """
  @impl true
  @spec load(String.t()) :: {:ok, JidoChat.Channel.t()} | {:error, :not_found}
  def load(channel_id) do
    case Agent.get(__MODULE__, &Map.get(&1, channel_id)) do
      nil -> {:error, :not_found}
      channel_state -> {:ok, channel_state}
    end
  end

  @doc """
  Deletes channel state from the in-memory store.

  Removes the channel_id and its associated state from the Agent's state map.

  ## Parameters
    * `channel_id` - Unique identifier for the channel to delete

  ## Returns
    * `:ok` - Always returns ok, even if channel did not exist
  """
  @impl true
  @spec delete(String.t()) :: :ok
  def delete(channel_id) do
    Agent.update(__MODULE__, &Map.delete(&1, channel_id))
  end
end
