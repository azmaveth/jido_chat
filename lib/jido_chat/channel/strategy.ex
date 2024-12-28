defmodule JidoChat.Channel.Strategy do
  @moduledoc """
  Defines the behavior for turn-taking strategies in chat channels.

  This module specifies the callbacks that must be implemented by any turn-taking strategy.
  Strategies control when participants can post messages and manage whose turn it is to speak.
  """

  @doc """
  Determines if a participant is allowed to post a message in the current channel state.

  ## Parameters
    * `channel` - The channel struct containing the current state
    * `participant_id` - The ID of the participant attempting to post

  ## Returns
    * `true` if the participant can post
    * `false` if the participant cannot post
  """
  @callback can_post?(JidoChat.Channel.t(), String.t()) :: boolean()

  @doc """
  Updates the channel state to reflect the next participant's turn.

  ## Parameters
    * `channel` - The current channel state

  ## Returns
    * The updated channel struct with the next participant's turn
  """
  @callback next_turn(JidoChat.Channel.t()) :: JidoChat.Channel.t()
end
