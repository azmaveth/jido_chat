defmodule JidoChat.ChannelTest do
  use ExUnit.Case
  alias JidoChat.Channel
  alias JidoChat.Channel.{Strategy, Persistence}
  alias JidoChat.{Message, Participant}

  setup do
    # Set the log level to debug for this test module
    Logger.configure(level: :debug)

    # Start the ETS persistence process
    start_supervised!(Persistence.ETS)

    channel_id = "test_channel_#{System.unique_integer()}"
    # For RoundRobin tests, we'll override the strategy in the specific setup
    {:ok, pid} = Channel.start_link(channel_id)

    %{channel_id: channel_id, pid: pid}
  end

  describe "Channel" do
    test "start_link/1 creates a new channel", %{channel_id: _channel_id, pid: pid} do
      assert is_pid(pid)
      assert Process.alive?(pid)

      # Test with custom options
      new_channel_id = "test_channel_#{System.unique_integer()}"

      {:ok, custom_pid} =
        Channel.start_link(new_channel_id, strategy: Strategy.RoundRobin, message_limit: 50)

      assert is_pid(custom_pid)
      assert Process.alive?(custom_pid)
    end

    test "post_message/3 adds a message to the channel", %{pid: pid} do
      participant = %Participant{id: "user1", name: "User 1", type: :human}
      :ok = Channel.join(pid, participant)

      {:ok, message} = Channel.post_message(pid, "user1", "Hello, world!")
      assert %Message{} = message
      assert message.content == "Hello, world!"
      assert message.participant_id == "user1"

      # Test message limit
      limited_channel_id = "limited_channel_#{System.unique_integer()}"
      {:ok, limited_pid} = Channel.start_link(limited_channel_id, message_limit: 2)
      :ok = Channel.join(limited_pid, participant)
      {:ok, _} = Channel.post_message(limited_pid, "user1", "Message 1")
      {:ok, _} = Channel.post_message(limited_pid, "user1", "Message 2")
      {:ok, _} = Channel.post_message(limited_pid, "user1", "Message 3")

      # Get messages in reverse chronological order (newest first)
      {:ok, messages} = Channel.get_messages(limited_pid, order: :reverse_chronological)
      assert length(messages) == 2
      assert Enum.map(messages, & &1.content) == ["Message 3", "Message 2"]
    end

    test "join/2 adds a participant to the channel", %{pid: pid} do
      participant = %Participant{id: "user2", name: "User 2", type: :human}
      assert :ok = Channel.join(pid, participant)

      # Attempt to join again should fail
      assert {:ok, :already_joined} = Channel.join(pid, participant)

      # Verify participant was added
      {:ok, participants} = Channel.get_participants(pid)
      assert Enum.any?(participants, &(&1.id == "user2"))
    end

    test "leave/2 removes a participant from the channel", %{pid: pid} do
      participant = %Participant{id: "user3", name: "User 3", type: :human}
      :ok = Channel.join(pid, participant)
      assert :ok = Channel.leave(pid, participant.id)

      # Posting a message after leaving should fail
      assert {:error, :not_allowed} = Channel.post_message(pid, participant.id, "Hello?")

      # Verify participant was removed
      {:ok, participants} = Channel.get_participants(pid)
      refute Enum.any?(participants, &(&1.id == "user3"))
    end

    test "get_messages/1 returns messages in correct order", %{pid: pid} do
      participant = %Participant{id: "user4", name: "User 4", type: :human}
      :ok = Channel.join(pid, participant)

      {:ok, _} = Channel.post_message(pid, "user4", "Message 1")
      {:ok, _} = Channel.post_message(pid, "user4", "Message 2")
      {:ok, _} = Channel.post_message(pid, "user4", "Message 3")

      # Test chronological order (default)
      {:ok, messages} = Channel.get_messages(pid)
      assert Enum.map(messages, & &1.content) == ["Message 1", "Message 2", "Message 3"]

      # Test reverse chronological order
      {:ok, messages} = Channel.get_messages(pid, order: :reverse_chronological)
      assert Enum.map(messages, & &1.content) == ["Message 3", "Message 2", "Message 1"]
    end

    test "get_participants/1 returns all participants", %{pid: pid} do
      participants = [
        %Participant{id: "user5", name: "User 5", type: :human},
        %Participant{id: "user6", name: "User 6", type: :human},
        %Participant{id: "agent1", name: "Agent 1", type: :agent}
      ]

      Enum.each(participants, &Channel.join(pid, &1))

      {:ok, channel_participants} = Channel.get_participants(pid)
      assert length(channel_participants) == 3
      assert Enum.all?(participants, &Enum.member?(channel_participants, &1))
    end

    test "can refer to channel by pid or channel_id", %{pid: pid, channel_id: channel_id} do
      participant = %Participant{id: "user7", name: "User 7", type: :human}

      :ok = Channel.join(pid, participant)

      assert {:ok, _} = Channel.post_message(channel_id, participant.id, "Message via channel_id")
      {:ok, messages_via_pid} = Channel.get_messages(pid)
      {:ok, messages_via_id} = Channel.get_messages(channel_id)
      assert messages_via_pid == messages_via_id
      assert :ok = Channel.leave(channel_id, participant.id)
      {:ok, participants} = Channel.get_participants(pid)
      refute Enum.any?(participants, &(&1.id == participant.id))
    end
  end

  describe "Channel with RoundRobin strategy" do
    setup %{channel_id: _channel_id} do
      Logger.configure(level: :debug)
      # Create a new channel with RoundRobin strategy
      channel_id = "test_channel_#{System.unique_integer()}"
      {:ok, pid} = Channel.start_link(channel_id, strategy: Strategy.RoundRobin)
      %{pid: pid}
    end

    test "enforces turn order for non-human participants", %{pid: pid} do
      human = %Participant{id: "human1", name: "Human 1", type: :human}
      agent1 = %Participant{id: "agent1", name: "Agent 1", type: :agent}
      agent2 = %Participant{id: "agent2", name: "Agent 2", type: :agent}

      :ok = Channel.join(pid, human)
      :ok = Channel.join(pid, agent1)
      :ok = Channel.join(pid, agent2)

      # Human can always post
      assert {:ok, _} = Channel.post_message(pid, "human1", "Human message")

      # First agent can post
      assert {:ok, _} = Channel.post_message(pid, "agent1", "Agent 1 message")

      # Second agent's turn
      assert {:error, :not_allowed} = Channel.post_message(pid, "agent1", "Out of turn")
      assert {:ok, _} = Channel.post_message(pid, "agent2", "Agent 2 message")

      # Back to first agent
      assert {:ok, _} = Channel.post_message(pid, "agent1", "Agent 1 again")

      # Test turn reset when all agents have posted
      assert {:ok, _} = Channel.post_message(pid, "agent2", "Agent 2 again")
      assert {:ok, _} = Channel.post_message(pid, "agent1", "New round")
    end

    test "handles agent leaving during their turn", %{pid: pid} do
      agent1 = %Participant{id: "agent1", name: "Agent 1", type: :agent}
      agent2 = %Participant{id: "agent2", name: "Agent 2", type: :agent}

      :ok = Channel.join(pid, agent1)
      :ok = Channel.join(pid, agent2)

      assert {:ok, _} = Channel.post_message(pid, "agent1", "Agent 1 message")
      :ok = Channel.leave(pid, "agent2")

      # Agent 1 should be able to post again as it's the only agent left
      assert {:ok, _} = Channel.post_message(pid, "agent1", "Agent 1 again")
    end
  end

  describe "Channel persistence" do
    test "loads existing channel on start_link", %{channel_id: _channel_id} do
      # Create and populate a channel
      channel_id = "test_channel_#{System.unique_integer()}"
      {:ok, pid1} = Channel.start_link(channel_id)
      :ok = Channel.join(pid1, %Participant{id: "user1", name: "User 1", type: :human})
      {:ok, _} = Channel.post_message(pid1, "user1", "Persistent message")

      # Stop the channel process
      GenServer.stop(pid1)

      # Start a new process for the same channel
      {:ok, pid2} = Channel.start_link(channel_id)

      # Check if the channel state was persisted
      {:ok, messages} = Channel.get_messages(pid2)
      assert length(messages) == 1
      assert hd(messages).content == "Persistent message"

      {:ok, participants} = Channel.get_participants(pid2)
      assert length(participants) == 1
      assert hd(participants).id == "user1"
    end
  end
end
