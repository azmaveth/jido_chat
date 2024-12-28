defmodule JidoChat.Channel.Strategy.FreeForm do
  @moduledoc """
  Implements a free-form chat strategy where all participants can post messages at any time.

  This is the simplest turn-taking strategy that places no restrictions on when participants
  can post messages. It's suitable for casual chat channels where strict turn order is not needed.

  ## Usage
  This strategy can be specified when creating a new channel:

      {:ok, channel} = JidoChat.Channel.new(strategy: JidoChat.Channel.Strategy.FreeForm)

  ## Behavior
  - All participants can post messages at any time
  - No concept of turns or turn order is maintained
  - No state tracking is required
  """

  @behaviour JidoChat.Channel.Strategy

  @doc """
  Always allows posting messages, regardless of channel state or participant.

  This implementation simply returns true for all participants, allowing unrestricted posting.

  ## Parameters
    * `_channel` - The channel struct (unused)
    * `_participant_id` - The ID of the participant attempting to post (unused)

  ## Returns
    * `{:ok, true}` - Always returns true since posting is unrestricted
  """
  @impl true
  def can_post?(_channel, _participant_id), do: {:ok, true}

  @doc """
  No-op implementation since free-form chat has no turn management.

  Simply returns the channel unchanged since turn order is not tracked.

  ## Parameters
    * `channel` - The current channel struct

  ## Returns
    * `{:ok, channel}` - Returns the unchanged channel
  """
  @impl true
  def next_turn(channel), do: {:ok, channel}
end
