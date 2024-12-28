defmodule JidoChat.Actions.Chat do
  @moduledoc """
  Actions for chat-related operations in workflows.

  This module provides a set of actions for chat-based interactions:
  - Evaluate: Evaluates an incoming message
  - Think: Processes an evaluation to generate thoughts
  - Respond: Generates a response based on thoughts

  Each action is implemented as a separate submodule and follows the Jido.Action behavior.
  """

  alias Jido.Action

  defmodule Evaluate do
    @moduledoc false
    use Action,
      name: "evaluate",
      description: "Evaluates an incoming message",
      schema: [
        message: [
          type: :string,
          required: true,
          doc: "The message to evaluate"
        ]
      ]

    @spec run(map(), map()) :: {:ok, map()}
    @impl true
    def run(%{message: message}, _context) do
      {:ok, %{message: message}}
    end
  end

  defmodule Think do
    @moduledoc false
    use Action,
      name: "think",
      description: "Processes an evaluation to generate thoughts",
      schema: [
        evaluation: [
          type: :map,
          required: true,
          doc: "The evaluation result to think about"
        ]
      ]

    @spec run(map(), map()) :: {:ok, map()}
    @impl true
    def run(%{evaluation: evaluation}, _context) do
      {:ok, %{evaluation: evaluation}}
    end
  end

  defmodule Respond do
    @moduledoc false
    use Action,
      name: "respond",
      description: "Generates a response based on thoughts",
      schema: [
        thought: [
          type: :map,
          required: true,
          doc: "The thought process to respond to"
        ],
        evaluation: [
          type: :map,
          required: true,
          doc: "The original evaluation"
        ]
      ]

    @spec run(map(), map()) :: {:ok, map()}
    @impl true
    def run(%{thought: thought, evaluation: evaluation}, _context) do
      {:ok,
       %{
         thought: thought,
         evaluation: evaluation,
         response: "Default response"
       }}
    end
  end

  defmodule EchoResponse do
    @moduledoc false
    use Action,
      name: "echo_response",
      description: "Echoes the response",
      schema: [
        prefix: [type: :string, required: true, doc: "The echo prefix"],
        thought: [
          type: :map,
          required: true,
          doc: "The thought process to respond to"
        ],
        evaluation: [
          type: :map,
          required: true,
          doc: "The original evaluation"
        ]
      ]

    @spec run(map(), map()) :: {:ok, map()}
    @impl true
    def run(%{prefix: prefix, thought: thought, evaluation: evaluation}, _context) do
      {:ok,
       %{
         thought: thought,
         evaluation: evaluation,
         response: "#{prefix} #{evaluation.message}"
       }}
    end
  end
end
