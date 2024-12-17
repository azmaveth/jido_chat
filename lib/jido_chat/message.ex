defmodule JidoChat.Message do
  @type t :: %__MODULE__{
          id: String.t(),
          content: String.t(),
          participant_id: String.t(),
          timestamp: DateTime.t(),
          metadata: map()
        }

  defstruct [:id, :content, :participant_id, :timestamp, metadata: %{}]
end
