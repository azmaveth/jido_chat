defmodule JidoChat.Participant do
  @moduledoc """
  Represents a participant in a chat channel.
  """

  @type participant_type :: :human | :agent
  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          type: participant_type(),
          metadata: map()
        }

  defstruct [:id, :name, :type, metadata: %{}]
end
