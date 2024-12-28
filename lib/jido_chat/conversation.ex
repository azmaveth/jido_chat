defmodule JidoChat.Conversation do
  @moduledoc """
  Represents a conversation context suitable for LLM processing.
  """
  alias JidoChat.Participant

  @type t :: %__MODULE__{
          messages: [formatted_message()],
          participants: [Participant.t()],
          metadata: map()
        }

  @type formatted_message :: %{
          role: String.t(),
          content: String.t(),
          name: String.t() | nil,
          metadata: map()
        }

  defstruct [:messages, :participants, metadata: %{}]

  @doc """
  Creates a conversation context from channel messages and participants.

  ## Options

    * `:message_limit` - Maximum number of messages to include (default: 10)
    * `:include_metadata` - Whether to include message metadata (default: false)
    * `:format` - Output format (:chat_ml | :anthropic | :raw) (default: :chat_ml)

  Returns {:ok, conversation} on success.
  """
  def from_messages(messages, participants, opts \\ []) do
    limit = Keyword.get(opts, :message_limit, 10)
    format = Keyword.get(opts, :format, :chat_ml)
    include_metadata = Keyword.get(opts, :include_metadata, false)

    formatted_messages =
      messages
      |> Enum.take(limit)
      |> Enum.map(&format_message(&1, participants, include_metadata))

    conversation = %__MODULE__{
      messages: formatted_messages,
      participants: participants,
      metadata: %{
        format: format,
        created_at: DateTime.utc_now(),
        message_count: length(formatted_messages)
      }
    }

    {:ok, conversation}
  end

  defp format_message(message, participants, include_metadata) do
    participant = Enum.find(participants, &(&1.id == message.participant_id))

    base_message = %{
      role: get_role(participant),
      content: message.content,
      name: participant && participant.name
    }

    if include_metadata do
      Map.put(base_message, :metadata, message.metadata)
    else
      base_message
    end
  end

  defp get_role(%{type: :human}), do: "user"
  defp get_role(%{type: :agent}), do: "assistant"
  defp get_role(_), do: "system"

  @doc """
  Converts the conversation to various LLM-specific formats.
  """
  def to_format(%__MODULE__{} = conversation, format) do
    case format do
      :chat_ml -> to_chat_ml(conversation)
      :anthropic -> to_anthropic(conversation)
      :raw -> {:ok, conversation.messages}
      _ -> {:error, :unsupported_format}
    end
  end

  defp to_chat_ml(conversation) do
    messages =
      Enum.map(conversation.messages, fn msg ->
        %{
          role: msg.role,
          content: msg.content,
          name: msg.name
        }
      end)

    {:ok, messages}
  end

  defp to_anthropic(conversation) do
    # Implement Anthropic's specific format
    {:ok, "Human: " <> format_anthropic_messages(conversation.messages)}
  end

  defp format_anthropic_messages(messages) do
    # Implementation for Anthropic's format
    messages
    |> Enum.map_join("\n\n", fn
      %{role: "user"} = msg -> "Human: #{msg.content}"
      %{role: "assistant"} = msg -> "Assistant: #{msg.content}"
      %{role: "system"} = msg -> msg.content
    end)
  end
end
