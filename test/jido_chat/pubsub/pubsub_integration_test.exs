defmodule JidoChat.Channel.PubSubIntegrationTest do
  use ExUnit.Case
  require Logger

  alias JidoChat.Channel
  alias JidoChat.Channel.Strategy
  alias JidoChat.{Message, Participant}
  alias Phoenix.PubSub

  setup do
    # Start ETS table for persistence
    :ets.new(:jido_channels, [:set, :public, :named_table, :named_table])

    channel_id = "test_channel_#{System.unique_integer()}"
    {:ok, pid} = Channel.start_link(channel_id, strategy: Strategy.PubSubRoundRobin)

    # Start a test process to collect messages
    test_pid = self()
    collector_pid = spawn_link(fn -> message_collector(test_pid, []) end)
    Process.register(collector_pid, :message_collector)

    # Subscribe to all channel messages
    channel_topic = "channel:#{channel_id}"
    :ok = PubSub.subscribe(JidoChat.PubSub, channel_topic)

    on_exit(fn ->
      if :ets.whereis(:jido_channels) != :undefined do
        :ets.delete(:jido_channels)
      end
    end)

    %{
      channel_id: channel_id,
      channel_topic: channel_topic,
      pid: pid,
      collector: collector_pid
    }
  end

  describe "Channel PubSub integration" do
    test "follows round-robin strategy for agent messages", %{pid: pid} do
      agent1 = %Participant{id: "agent1", name: "Agent 1", type: :agent}
      agent2 = %Participant{id: "agent2", name: "Agent 2", type: :agent}

      :ok = Channel.join(pid, agent1)
      :ok = Channel.join(pid, agent2)

      # First agent posts
      {:ok, msg1} = Channel.post_message(pid, "agent1", "First message")
      send(:message_collector, {:message, msg1})
      assert_receive {:message, %Message{participant_id: "agent1", content: "First message"}}

      # Second agent posts
      {:ok, msg2} = Channel.post_message(pid, "agent2", "Second message")
      send(:message_collector, {:message, msg2})
      assert_receive {:message, %Message{participant_id: "agent2", content: "Second message"}}

      # Back to first agent
      {:ok, msg3} = Channel.post_message(pid, "agent1", "Third message")
      send(:message_collector, {:message, msg3})
      assert_receive {:message, %Message{participant_id: "agent1", content: "Third message"}}

      # Give PubSub time to process
      Process.sleep(100)

      # Get collected messages
      messages = get_collected_messages()

      assert length(messages) == 3

      assert Enum.map(messages, & &1.content) == [
               "First message",
               "Second message",
               "Third message"
             ]

      assert Enum.map(messages, & &1.participant_id) == ["agent1", "agent2", "agent1"]
    end

    test "handles agent disconnection gracefully", %{pid: pid} do
      agent1 = %Participant{id: "agent1", name: "Agent 1", type: :agent}
      agent2 = %Participant{id: "agent2", name: "Agent 2", type: :agent}

      :ok = Channel.join(pid, agent1)
      :ok = Channel.join(pid, agent2)

      # Post messages and verify broadcasts
      {:ok, msg1} = Channel.post_message(pid, "agent1", "Before leaving")
      send(:message_collector, {:message, msg1})
      assert_receive {:message, %Message{participant_id: "agent1", content: "Before leaving"}}

      :ok = Channel.leave(pid, "agent1")

      {:ok, msg2} = Channel.post_message(pid, "agent2", "After agent1 left")
      send(:message_collector, {:message, msg2})
      assert_receive {:message, %Message{participant_id: "agent2", content: "After agent1 left"}}

      # Give PubSub time to process
      Process.sleep(100)

      # Get collected messages
      messages = get_collected_messages()

      assert length(messages) == 2
      assert Enum.map(messages, & &1.content) == ["Before leaving", "After agent1 left"]
    end
  end

  # Message collector process with parent process reference
  defp message_collector(parent_pid, messages) do
    receive do
      {:message, msg} = message when is_struct(msg, Message) ->
        message_collector(parent_pid, [msg | messages])

      {:get_messages, from} ->
        collected = Enum.reverse(messages)
        send(from, {:collected_messages, collected})
        message_collector(parent_pid, [])

      _ ->
        message_collector(parent_pid, messages)
    end
  end

  # Helper to get messages from collector
  defp get_collected_messages do
    send(:message_collector, {:get_messages, self()})

    receive do
      {:collected_messages, messages} -> messages
    after
      1000 -> []
    end
  end
end
