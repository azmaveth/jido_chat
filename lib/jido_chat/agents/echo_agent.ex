defmodule JidoChat.EchoAgent do
  @moduledoc """
  A simple agent that can respond in a chat-like fashion using ChatCommand.
  """

  use Jido.Agent,
    name: "EchoAgent",
    schema: [
      battery_level: [type: :integer, default: 100]
    ],
    actions: [
      JidoChat.ChatCommand
    ]
end
