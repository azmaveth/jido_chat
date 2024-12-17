defmodule JidoChat.Room.Strategy do
  @callback can_post?(JidoChat.Room.t(), String.t()) :: boolean()
  @callback next_turn(JidoChat.Room.t()) :: JidoChat.Room.t()
end
