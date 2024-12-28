defmodule JidoChat.Channel.Strategy.FreeForm do
  @behaviour JidoChat.Channel.Strategy

  @impl true
  def can_post?(_channel, _participant_id), do: true

  @impl true
  def next_turn(channel), do: channel
end
