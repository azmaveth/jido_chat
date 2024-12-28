defmodule JidoChat.Actions.ChatTest do
  use ExUnit.Case, async: true
  alias JidoChat.Actions.Chat.{Evaluate, Think, Respond, EchoResponse}
  @moduletag :capture_log
  describe "Evaluate" do
    test "evaluates a message" do
      message = "test message"
      assert {:ok, %{message: ^message}} = Evaluate.run(%{message: message}, %{})
    end
  end

  describe "Think" do
    test "processes an evaluation" do
      evaluation = %{message: "test"}
      assert {:ok, %{evaluation: ^evaluation}} = Think.run(%{evaluation: evaluation}, %{})
    end
  end

  describe "Respond" do
    test "generates a response" do
      thought = %{message: "test thought"}
      evaluation = %{message: "test eval"}

      assert {:ok, result} = Respond.run(%{thought: thought, evaluation: evaluation}, %{})
      assert result.thought == thought
      assert result.evaluation == evaluation
      assert result.response == "Default response"
    end
  end

  describe "EchoResponse" do
    test "echoes the message with prefix" do
      thought = %{message: "hello"}
      evaluation = %{message: "test"}
      prefix = "Echo:"

      assert {:ok, result} =
               EchoResponse.run(%{prefix: prefix, thought: thought, evaluation: evaluation}, %{})

      assert result.thought == thought
      assert result.evaluation == evaluation
      assert result.response == "Echo: test"
    end
  end

  describe "Chat" do
    test "runs evaluate-think-respond workflow" do
      message = "test message"
      {:ok, evaluation} = Evaluate.run(%{message: message}, %{})
      {:ok, thought} = Think.run(%{evaluation: evaluation}, %{})
      assert {:ok, result} = Respond.run(%{thought: thought, evaluation: evaluation}, %{})
      assert result.response == "Default response"
    end
  end

  describe "EchoChat" do
    test "runs evaluate-think-echo workflow" do
      message = "test message"
      {:ok, evaluation} = Evaluate.run(%{message: message}, %{})
      {:ok, thought} = Think.run(%{evaluation: evaluation}, %{})

      assert {:ok, result} =
               EchoResponse.run(%{prefix: "Echo:", thought: thought, evaluation: evaluation}, %{})

      assert result.response == "Echo: test message"
    end
  end
end
