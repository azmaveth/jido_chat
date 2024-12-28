defmodule JidoChat.Application do
  @moduledoc """
  The JidoChat Application module manages the supervision tree and startup of core system components.

  This module initializes and supervises the following critical services:

  - Channel Registry: Tracks active chat channels using Registry
  - Persistence Layer: Manages chat history and state persistence
  - PubSub System: Handles real-time message broadcasting
  - Message Broker: Coordinates message delivery between participants

  The supervision strategy is one_for_one, meaning if any child process crashes,
  only that process is restarted while others continue running.
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    # Initializes the supervision tree with core system components.
    # Each child is started in order and supervised independently.
    # Returns {:ok, pid} on successful startup, {:error, reason} on failure.
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

    # Configure supervision options
    opts = [strategy: :one_for_one, name: JidoChat.Supervisor]

    # Start the supervisor with the child specifications
    Supervisor.start_link(children, opts)
  end
end
