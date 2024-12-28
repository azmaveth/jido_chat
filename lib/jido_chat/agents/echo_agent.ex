# defmodule JidoChat.EchoAgent do
#   @moduledoc """
#   A simple agent that can respond in a chat-like fashion using ChatCommand.
#   """

#   use Jido.Agent,
#     name: "EchoAgent",
#     schema: [
#       battery_level: [type: :integer, default: 100]
#     ],
#     actions: [
#       JidoChat.ChatCommand
#     ]

#   # Override the default error handler to allow for recovery
#   def on_error(_agent, reason) do
#     # Log the error
#     require Logger
#     Logger.warning("EchoAgent error: #{inspect(reason)}")

#     # Return error tuple directly since on_error is typed to return {:error, term()}
#     {:error, reason}
#   end

#   # Modify the error handling pattern matches in run/2 and cmd/4
#   def handle_error(agent, reason) do
#     case on_error(agent, reason) do
#       {:error, _} = error -> error
#       other -> {:error, {:unexpected_error_handler_response, other}}
#     end
#   end
# end
