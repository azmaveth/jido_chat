defmodule JidoChat.Message do
  @type message_type ::
          :text
          | :attachment
          | :audio
          | :system
          | :reaction
          | :other

  @type t :: %__MODULE__{
          id: String.t(),
          content: String.t(),
          type: message_type(),
          participant_id: String.t(),
          timestamp: DateTime.t(),
          metadata: map()
        }

  defstruct [:id, :content, :type, :participant_id, :timestamp, metadata: %{}]

  @doc """
  Creates a new message with the given content and participant ID.
  Automatically sets the type to :text unless specified in options.

  ## Options
    * `:type` - The message type (default: :text)
    * `:metadata` - Additional metadata for the message (default: %{})
    * `:id` - Custom ID for the message (default: generated UUID)
    * `:timestamp` - Custom timestamp (default: current UTC time)

  ## Examples
      iex> create("Hello!", "user1")
      {:ok, %JidoChat.Message{content: "Hello!", participant_id: "user1", type: :text}}

      iex> create("file.jpg", "user1", type: :attachment)
      {:ok, %JidoChat.Message{content: "file.jpg", participant_id: "user1", type: :attachment}}
  """
  def create(content, participant_id, opts \\ [])
      when is_binary(content) and is_binary(participant_id) do
    type = Keyword.get(opts, :type, :text)
    metadata = Keyword.get(opts, :metadata, %{})

    if type not in [:text, :attachment, :audio, :system, :reaction, :other] do
      {:error, :invalid_message_type}
    else
      message = %__MODULE__{
        id: Keyword.get(opts, :id, UUID.uuid4()),
        content: content,
        type: type,
        participant_id: participant_id,
        timestamp: Keyword.get(opts, :timestamp, DateTime.utc_now()),
        metadata: metadata
      }

      {:ok, message}
    end
  end

  @doc """
  Creates a new system message.

  ## Examples
      iex> system_message("User joined the chat", "system")
      {:ok, %JidoChat.Message{content: "User joined the chat", type: :system}}
  """
  def system_message(content, participant_id \\ "system") do
    create(content, participant_id, type: :system)
  end

  @doc """
  Adds metadata to an existing message.
  """
  def add_metadata(%__MODULE__{} = message, key, value) when is_atom(key) do
    %{message | metadata: Map.put(message.metadata, key, value)}
  end

  @doc """
  Returns true if the message is from the given participant.
  """
  def from_participant?(%__MODULE__{} = message, participant_id) do
    message.participant_id == participant_id
  end
end
