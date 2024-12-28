defmodule JidoChat.PubSub.MessageBrokerTest do
  use ExUnit.Case, async: true
  require Logger

  alias JidoChat.PubSub.MessageBroker
  alias JidoChat.{Message, Participant}
  alias Phoenix.PubSub

  @moduletag :capture_log

  setup do
    channel_id = "test_channel_#{System.unique_integer()}"
    {:ok, broker} = MessageBroker.start_link(channel_id: channel_id)

    %{
      channel_id: channel_id,
      broker: broker
    }
  end

  describe "MessageBroker initialization" do
    test "successfully starts with valid channel_id", %{channel_id: channel_id} do
      {:ok, pid} = MessageBroker.start_link(channel_id: channel_id)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "fails to start without channel_id" do
      Process.flag(:trap_exit, true)
      {:error, {%KeyError{key: :channel_id}, _stacktrace}} = MessageBroker.start_link([])
    end

    test "uses default RoundRobin strategy when none specified", %{channel_id: channel_id} do
      {:ok, pid} = MessageBroker.start_link(channel_id: channel_id)
      state = :sys.get_state(pid)
      assert state.strategy == JidoChat.Channel.Strategy.RoundRobin
    end

    test "accepts custom strategy", %{channel_id: channel_id} do
      custom_strategy = JidoChat.Channel.Strategy.PubSubRoundRobin
      {:ok, pid} = MessageBroker.start_link(channel_id: channel_id, strategy: custom_strategy)
      state = :sys.get_state(pid)
      assert state.strategy == custom_strategy
    end
  end

  describe "participant registration" do
    test "registers participant and topic", %{broker: broker, channel_id: channel_id} do
      participant = %Participant{id: "user1", name: "User 1", type: :human}
      topic = "test_topic"

      :ok = PubSub.subscribe(JidoChat.PubSub, topic)
      :ok = PubSub.subscribe(JidoChat.PubSub, "channel:#{channel_id}")

      assert :ok = MessageBroker.register_participant(broker, participant, topic)

      state = :sys.get_state(broker)
      assert Map.get(state.participants, participant.id) == participant
      assert Map.get(state.topic_registry, participant.id) == topic
    end

    test "updates existing participant registration", %{broker: broker} do
      participant = %Participant{id: "user1", name: "User 1", type: :human}
      updated_participant = %{participant | name: "Updated User 1"}

      :ok = MessageBroker.register_participant(broker, participant, "topic1")
      :ok = MessageBroker.register_participant(broker, updated_participant, "topic2")

      state = :sys.get_state(broker)
      assert Map.get(state.participants, participant.id) == updated_participant
      assert Map.get(state.topic_registry, participant.id) == "topic2"
    end
  end

  describe "message broadcasting" do
    test "broadcasts messages to correct topics", %{broker: broker, channel_id: channel_id} do
      participant = %Participant{id: "agent1", name: "Agent 1", type: :agent}
      topic = "agent1_topic"
      channel_topic = "channel:#{channel_id}"

      :ok = PubSub.subscribe(JidoChat.PubSub, topic)
      :ok = PubSub.subscribe(JidoChat.PubSub, channel_topic)
      :ok = MessageBroker.register_participant(broker, participant, topic)

      message = %Message{content: "test message", participant_id: "agent1"}
      MessageBroker.broadcast(broker, topic, message)

      assert_receive {:message, ^message}
      assert_receive {:message, ^message}
    end

    test "handles turn notifications for agent messages", %{
      broker: broker,
      channel_id: channel_id
    } do
      agent1 = %Participant{id: "agent1", name: "Agent 1", type: :agent}
      agent2 = %Participant{id: "agent2", name: "Agent 2", type: :agent}

      agent1_topic = "agent1_topic"
      agent2_topic = "agent2_topic"

      :ok = MessageBroker.register_participant(broker, agent1, agent1_topic)
      :ok = MessageBroker.register_participant(broker, agent2, agent2_topic)
      :ok = PubSub.subscribe(JidoChat.PubSub, agent2_topic)

      message = %Message{content: "test message", participant_id: "agent1"}
      MessageBroker.broadcast(broker, agent1_topic, message)

      assert_receive {:turn_notification, "agent2"}
    end

    test "does not send turn notifications for human messages", %{broker: broker} do
      human = %Participant{id: "user1", name: "User 1", type: :human}
      agent = %Participant{id: "agent1", name: "Agent 1", type: :agent}

      :ok = MessageBroker.register_participant(broker, human, "user_topic")
      :ok = MessageBroker.register_participant(broker, agent, "agent_topic")
      :ok = PubSub.subscribe(JidoChat.PubSub, "agent_topic")

      message = %Message{content: "test message", participant_id: "user1"}
      MessageBroker.broadcast(broker, "user_topic", message)

      refute_receive {:turn_notification, _}
    end
  end

  describe "topic subscription" do
    test "successfully subscribes to topics", %{broker: broker} do
      topic = "test_topic"
      :ok = MessageBroker.subscribe(broker, topic)
      :ok = PubSub.subscribe(JidoChat.PubSub, topic)

      # Subscribe to the channel topic as well
      channel_topic = "channel:test_channel_#{System.unique_integer()}"
      :ok = PubSub.subscribe(JidoChat.PubSub, channel_topic)

      # Broadcast a message to verify subscription
      message = %Message{content: "test", participant_id: "test"}
      :ok = PubSub.broadcast(JidoChat.PubSub, topic, {:message, message})

      # The broker should receive and rebroadcast the message
      assert_receive {:message, ^message}, 500
    end
  end
end
