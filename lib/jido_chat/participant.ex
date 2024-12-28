defmodule JidoChat.Participant do
  @moduledoc """
  Represents a participant in a chat channel with associated metadata and type information.

  This module defines the core participant data structure used throughout the chat system.
  It supports both human users and AI agents as participants, with extensible metadata
  for storing additional participant-specific information.

  ## Participant Types

  The following participant types are supported:
  - `:human` - Human users participating in the chat
  - `:agent` - AI agents or bots participating in the chat

  ## Features

  - Unique participant identification
  - Type-based role assignment
  - Custom name support
  - Extensible metadata storage
  - Type safety with comprehensive typespecs

  ## Examples

      # Create a human participant
      %Participant{
        id: "user123",
        name: "John Doe",
        type: :human,
        metadata: %{avatar_url: "https://..."}
      }

      # Create an AI agent participant
      %Participant{
        id: "agent007",
        name: "Assistant",
        type: :agent,
        metadata: %{capabilities: [:chat, :image_gen]}
      }
  """

  @typedoc """
  The type of participant - either a human user or an AI agent.
  """
  @type participant_type :: :human | :agent

  @typedoc """
  A participant struct containing:
  - `id`: Unique participant identifier
  - `name`: Display name of the participant
  - `type`: The participant type (see `t:participant_type/0`)
  - `metadata`: Additional participant metadata like preferences, capabilities, etc
  """
  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          type: participant_type(),
          metadata: map()
        }
  @enforce_keys [:id, :name, :type]
  defstruct [:id, :name, :type, metadata: %{}]
end
