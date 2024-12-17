defmodule JidoChat.Room.Strategy.FreeForm do
  @behaviour JidoChat.Room.Strategy

  @impl true
  def can_post?(_room, _participant_id), do: true

  @impl true
  def next_turn(room), do: room
end
