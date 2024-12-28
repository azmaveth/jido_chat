defmodule JidoChat.Channel.Persistence do
  @moduledoc """
  Defines persistence behavior and provides functions for saving, loading and managing channel state.

  This module provides a behavior specification and convenience functions for persisting chat channel
  state across different storage backends. It allows for flexible storage options while maintaining
  a consistent interface.

  ## Persistence Adapters

  The module supports pluggable persistence adapters that must implement the following callbacks:
  - `save/2` - Save channel state
  - `load/1` - Load channel state
  - `delete/1` - Delete channel state

  Built-in adapters include:
  - `JidoChat.Channel.Persistence.ETS` - In-memory storage using ETS tables
  - `JidoChat.Channel.Persistence.Agent` - Process-based storage using Agents

  ## Usage Example

      # Using the default ETS adapter
      {:ok, channel} = JidoChat.Channel.Persistence.load("channel-123")

      # Using a custom adapter
      :ok = JidoChat.Channel.Persistence.save("channel-123", channel, MyCustomAdapter)

  ## Error Handling

  All operations return tagged tuples to indicate success/failure:
  - `{:ok, result}` for successful operations
  - `{:error, reason}` for failures

  Common error reasons include:
  - `:not_found` - Channel does not exist
  - `:invalid_state` - Channel state is invalid
  - `:storage_error` - Storage backend error
  """

  @doc """
  Callback for saving a channel's state.

  ## Parameters
    * `channel_id` - Unique identifier for the channel
    * `channel_state` - Complete channel state to persist

  ## Returns
    * `:ok` on successful save
    * `{:error, reason}` if save fails
  """
  @callback save(String.t(), JidoChat.Channel.t()) :: :ok | {:error, term()}

  @doc """
  Callback for loading a channel's state.

  ## Parameters
    * `channel_id` - Unique identifier for the channel to load

  ## Returns
    * `{:ok, channel}` with loaded channel state
    * `{:error, :not_found}` if channel does not exist
    * `{:error, reason}` for other failures
  """
  @callback load(String.t()) :: {:ok, JidoChat.Channel.t()} | {:error, term()}

  @doc """
  Callback for deleting a channel's state.

  ## Parameters
    * `channel_id` - Unique identifier for the channel to delete

  ## Returns
    * `:ok` on successful deletion
    * `{:error, reason}` if deletion fails
  """
  @callback delete(String.t()) :: :ok | {:error, term()}

  @doc """
  Saves a channel's state using the specified persistence adapter.

  Persists the complete channel state including messages, participants, and metadata
  using the provided adapter implementation.

  ## Parameters
    * `channel_id` - The unique identifier for the channel
    * `channel_state` - The complete channel state to persist
    * `adapter` - The persistence adapter module to use (defaults to ETS)

  ## Returns
    * `:ok` on successful save
    * `{:error, reason}` if save fails

  ## Examples

      iex> channel = %JidoChat.Channel{id: "123", name: "Test Channel"}
      iex> JidoChat.Channel.Persistence.save("123", channel)
      :ok

      iex> JidoChat.Channel.Persistence.save("123", invalid_state)
      {:error, :invalid_state}
  """
  @spec save(String.t(), JidoChat.Channel.t(), module()) :: :ok | {:error, term()}
  def save(channel_id, channel_state, adapter \\ JidoChat.Channel.Persistence.ETS) do
    adapter.save(channel_id, channel_state)
  end

  @doc """
  Loads a channel's state using the specified persistence adapter.

  Retrieves the complete channel state from storage, including all messages,
  participants and metadata.

  ## Parameters
    * `channel_id` - The unique identifier for the channel
    * `adapter` - The persistence adapter module to use (defaults to ETS)

  ## Returns
    * `{:ok, channel}` with loaded channel state
    * `{:error, :not_found}` if channel does not exist
    * `{:error, reason}` for other failures

  ## Examples

      iex> JidoChat.Channel.Persistence.load("existing-channel")
      {:ok, %JidoChat.Channel{id: "existing-channel", ...}}

      iex> JidoChat.Channel.Persistence.load("missing-channel")
      {:error, :not_found}
  """
  @spec load(String.t(), module()) :: {:ok, JidoChat.Channel.t()} | {:error, term()}
  def load(channel_id, adapter \\ JidoChat.Channel.Persistence.ETS) do
    adapter.load(channel_id)
  end

  @doc """
  Deletes a channel's state using the specified persistence adapter.

  Completely removes the channel and all associated data from storage.

  ## Parameters
    * `channel_id` - The unique identifier for the channel
    * `adapter` - The persistence adapter module to use (defaults to ETS)

  ## Returns
    * `:ok` on successful deletion
    * `{:error, reason}` if deletion fails

  ## Examples

      iex> JidoChat.Channel.Persistence.delete("channel-to-remove")
      :ok

      iex> JidoChat.Channel.Persistence.delete("missing-channel")
      {:error, :not_found}
  """
  @spec delete(String.t(), module()) :: :ok | {:error, term()}
  def delete(channel_id, adapter \\ JidoChat.Channel.Persistence.ETS) do
    adapter.delete(channel_id)
  end

  @doc """
  Loads an existing channel or creates a new one if not found.

  This is a convenience function that attempts to load a channel, and if not found,
  creates a new channel with default settings.

  ## Parameters
    * `channel_id` - The unique identifier for the channel
    * `adapter` - The persistence adapter module to use (defaults to ETS)

  ## Returns
    * `{:ok, channel}` with either the loaded or newly created channel

  ## Examples

      iex> JidoChat.Channel.Persistence.load_or_create("new-channel")
      {:ok, %JidoChat.Channel{id: "new-channel", name: "Channel new-channel"}}

      iex> JidoChat.Channel.Persistence.load_or_create("existing-channel")
      {:ok, %JidoChat.Channel{id: "existing-channel", ...}}
  """
  @spec load_or_create(String.t(), module()) :: {:ok, JidoChat.Channel.t()}
  def load_or_create(channel_id, adapter \\ JidoChat.Channel.Persistence.ETS) do
    case load(channel_id, adapter) do
      {:ok, channel} ->
        {:ok, channel}

      {:error, :not_found} ->
        {:ok, %JidoChat.Channel{id: channel_id, name: "Channel #{channel_id}"}}
    end
  end
end
