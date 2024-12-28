defmodule JidoChat.Application do
  @moduledoc false
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children =
      [
        # Start the Channel Registry
        {Registry, name: JidoChat.ChannelRegistry, keys: :unique},

        # Start the Persistence layer
        JidoChat.Channel.Persistence.Memory,

        # Start our PubSub
        {Phoenix.PubSub, name: JidoChat.PubSub},

        # Start the MessageBroker
        {JidoChat.PubSub.MessageBroker, [channel_id: "global"]}
      ]
      |> Enum.reject(&is_nil/1)

    opts = [strategy: :one_for_one, name: JidoChat.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
