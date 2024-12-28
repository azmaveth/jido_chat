defmodule JidoChat.Channel.Persistence do
  @moduledoc """
  Defines persistence behavior and provides functions for saving, loading and managing channel state.
  """

  @doc """
  Callback for saving a channel's state.
  """
  @callback save(String.t(), JidoChat.Channel.t()) :: :ok | {:error, term()}

  @doc """
  Callback for loading a channel's state.
  """
  @callback load(String.t()) :: {:ok, JidoChat.Channel.t()} | {:error, term()}

  @doc """
  Callback for deleting a channel's state.
  """
  @callback delete(String.t()) :: :ok | {:error, term()}

  @doc """
  Saves a channel's state using the specified persistence adapter.

  ## Parameters
    * `channel_id` - The unique identifier for the channel
    * `channel_state` - The channel state to persist
    * `adapter` - The persistence adapter to use (defaults to ETS)

  ## Returns
    * `:ok` on success
    * `{:error, reason}` on failure
  """
  @spec save(String.t(), JidoChat.Channel.t(), module()) :: :ok | {:error, term()}
  def save(channel_id, channel_state, adapter \\ JidoChat.Channel.Persistence.ETS) do
    adapter.save(channel_id, channel_state)
  end

  @doc """
  Loads a channel's state using the specified persistence adapter.

  ## Parameters
    * `channel_id` - The unique identifier for the channel
    * `adapter` - The persistence adapter to use (defaults to ETS)

  ## Returns
    * `{:ok, channel}` on success
    * `{:error, reason}` on failure
  """
  @spec load(String.t(), module()) :: {:ok, JidoChat.Channel.t()} | {:error, term()}
  def load(channel_id, adapter \\ JidoChat.Channel.Persistence.ETS) do
    adapter.load(channel_id)
  end

  @doc """
  Deletes a channel's state using the specified persistence adapter.

  ## Parameters
    * `channel_id` - The unique identifier for the channel
    * `adapter` - The persistence adapter to use (defaults to ETS)

  ## Returns
    * `:ok` on success
    * `{:error, reason}` on failure
  """
  @spec delete(String.t(), module()) :: :ok | {:error, term()}
  def delete(channel_id, adapter \\ JidoChat.Channel.Persistence.ETS) do
    adapter.delete(channel_id)
  end

  @doc """
  Loads an existing channel or creates a new one if not found.

  ## Parameters
    * `channel_id` - The unique identifier for the channel
    * `adapter` - The persistence adapter to use (defaults to ETS)

  ## Returns
    * `{:ok, channel}` with either the loaded or newly created channel
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
