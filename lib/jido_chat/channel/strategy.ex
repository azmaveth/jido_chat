defmodule JidoChat.Channel.Strategy do
  @moduledoc """
  Defines the behavior for turn-taking strategies in chat channels.

  This module specifies the callbacks that must be implemented by any turn-taking strategy.
  Strategies control when participants can post messages and manage whose turn it is to speak.

  ## Strategy Types
  Different strategies can be implemented to support various chat interaction patterns:
  - Free-form: All participants can post at any time
  - Round-robin: Participants take turns in order
  - Moderated: A moderator controls who can post
  - AI-assisted: Turn management guided by AI rules

  ## Implementation Example
      defmodule MyApp.RoundRobinStrategy do
        @behaviour JidoChat.Channel.Strategy

        @impl true
        def can_post?(channel, participant_id) do
          # Check if it's this participant's turn
          if channel.current_turn == participant_id do
            {:ok, true}
          else
            {:ok, false}
          end
        end

        @impl true
        def next_turn(channel) do
          # Rotate to next participant
          next = get_next_participant(channel)
          {:ok, %{channel | current_turn: next}}
        end
      end

  ## Error Handling
  Strategy implementations should return tagged tuples for both success and error cases:
  - `{:ok, result}` for successful operations
  - `{:error, reason}` for failures, using the defined strategy_error types
  """

  @typedoc """
  Possible error types that can be returned by strategy operations:
  - `:invalid_participant` - The participant ID is not valid or not in the channel
  - `:invalid_channel_state` - The channel is in an invalid state for the operation
  - `:turn_violation` - The participant tried to post out of turn
  """
  @type strategy_error ::
          :invalid_participant
          | :invalid_channel_state
          | :turn_violation
  @type strategy_result(t) :: {:ok, t} | {:error, strategy_error()}
  @type post_result :: strategy_result(boolean())
  @type turn_result :: strategy_result(JidoChat.Channel.t())

  @doc """
  Determines if a participant is allowed to post a message in the current channel state.

  This callback should implement the core turn-taking logic by checking if the given
  participant is currently allowed to post messages based on the strategy rules.

  ## Parameters
    * `channel` - The channel struct containing the current state, including participants,
      messages, and turn information
    * `participant_id` - The ID of the participant attempting to post a message

  ## Returns
    * `{:ok, true}` if the participant can post
    * `{:ok, false}` if the participant cannot post
    * `{:error, reason}` if there was an error checking posting permissions

  ## Example Implementation
      def can_post?(channel, participant_id) do
        cond do
          not participant_exists?(channel, participant_id) ->
            {:error, :invalid_participant}
          channel.current_turn == participant_id ->
            {:ok, true}
          true ->
            {:ok, false}
        end
      end
  """
  @callback can_post?(JidoChat.Channel.t(), String.t()) ::
              {:ok, boolean()}
              | {:error, strategy_error()}

  @doc """
  Updates the channel state to reflect the next participant's turn.

  This callback should implement the logic for transitioning turns between participants
  according to the strategy's rules. It receives the current channel state and should
  return an updated channel with the next participant's turn.

  ## Parameters
    * `channel` - The current channel state containing all participants and turn information

  ## Returns
    * `{:ok, updated_channel}` with the next participant's turn set
    * `{:error, reason}` if there was an error transitioning turns

  ## Example Implementation
      def next_turn(channel) do
        case get_next_participant(channel) do
          {:ok, next_id} ->
            {:ok, %{channel | current_turn: next_id}}
          {:error, reason} ->
            {:error, reason}
        end
      end
  """
  @callback next_turn(JidoChat.Channel.t()) ::
              {:ok, JidoChat.Channel.t()}
              | {:error, strategy_error()}
end
