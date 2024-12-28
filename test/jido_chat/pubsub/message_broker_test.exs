defmodule JidoChat.PubSub.MessageBrokerTest do
  use ExUnit.Case, async: true
  require Logger

  alias JidoChat.PubSub.MessageBroker
  alias JidoChat.{Message, Participant}
  alias Phoenix.PubSub

  setup do
    # Start Phoenix.PubSub for each test
    # start_supervised!({Phoenix.PubSub, name: JidoChat.PubSub})

    channel_id = "test_channel_#{System.unique_integer()}"
    {:ok, broker} = MessageBroker.start_link(channel_id: channel_id)

    %{
      channel_id: channel_id,
      broker: broker
    }
  end

  describe "MessageBroker" do
    test "successfully starts with valid channel_id", %{channel_id: channel_id} do
      {:ok, pid} = MessageBroker.start_link(channel_id: channel_id)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "registers participant and topic", %{broker: broker, channel_id: channel_id} do
      participant = %Participant{id: "user1", name: "User 1", type: :human}
      topic = "test_topic"

      # Subscribe to the topic to receive broadcasts
      :ok = PubSub.subscribe(JidoChat.PubSub, topic)
      :ok = PubSub.subscribe(JidoChat.PubSub, "channel:#{channel_id}")

      assert :ok = MessageBroker.register_participant(broker, participant, topic)

      message = %Message{content: "test message", participant_id: "user1"}
      MessageBroker.broadcast(broker, topic, message)

      assert_receive {:message, ^message}, 500
    end

    test "broadcasts messages to correct topics", %{broker: broker, channel_id: channel_id} do
      participant = %Participant{id: "agent1", name: "Agent 1", type: :agent}
      topic = "agent1_topic"
      channel_topic = "channel:#{channel_id}"

      # Subscribe to both topics
      :ok = PubSub.subscribe(JidoChat.PubSub, topic)
      :ok = PubSub.subscribe(JidoChat.PubSub, channel_topic)

      :ok = MessageBroker.register_participant(broker, participant, topic)

      message = %Message{content: "test message", participant_id: "agent1"}
      MessageBroker.broadcast(broker, topic, message)

      # Should receive message on both topics
      assert_receive {:message, ^message}, 500
      assert_receive {:message, ^message}, 500
    end
  end
end
