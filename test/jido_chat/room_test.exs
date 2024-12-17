defmodule JidoChat.RoomTest do
  use ExUnit.Case, async: true
  alias JidoChat.Room
  alias JidoChat.Room.{Strategy, Persistence}
  alias JidoChat.{Message, Participant}

  setup do
    # Set the log level to debug for this test module
    Logger.configure(level: :debug)

    # Start the ETS persistence process
    start_supervised!(Persistence.ETS)

    room_id = "test_room_id"
    # For RoundRobin tests, we'll override the strategy in the specific setup
    {:ok, pid} = Room.start_link(room_id)

    %{room_id: room_id, pid: pid}
  end

  describe "Room" do
    test "start_link/1 creates a new room", %{room_id: room_id, pid: pid} do
      assert is_pid(pid)
      assert Process.alive?(pid)

      # Test with custom options
      {:ok, custom_pid} =
        Room.start_link(room_id, strategy: Strategy.RoundRobin, message_limit: 50)

      assert is_pid(custom_pid)
      assert Process.alive?(custom_pid)
    end

    test "post_message/3 adds a message to the room", %{pid: pid} do
      participant = %Participant{id: "user1", name: "User 1", type: :human}
      :ok = Room.join(pid, participant)

      {:ok, message} = Room.post_message(pid, "user1", "Hello, world!")
      assert %Message{} = message
      assert message.content == "Hello, world!"
      assert message.participant_id == "user1"

      # Test message limit
      {:ok, limited_pid} = Room.start_link("limited_room", message_limit: 2)
      :ok = Room.join(limited_pid, participant)
      {:ok, _} = Room.post_message(limited_pid, "user1", "Message 1")
      {:ok, _} = Room.post_message(limited_pid, "user1", "Message 2")
      {:ok, _} = Room.post_message(limited_pid, "user1", "Message 3")

      # Get messages in reverse chronological order (newest first)
      {:ok, messages} = Room.get_messages(limited_pid, order: :reverse_chronological)
      assert length(messages) == 2
      assert Enum.map(messages, & &1.content) == ["Message 3", "Message 2"]
    end

    test "join/2 adds a participant to the room", %{pid: pid} do
      participant = %Participant{id: "user2", name: "User 2", type: :human}
      assert :ok = Room.join(pid, participant)

      # Attempt to join again should fail
      assert {:error, :already_joined} = Room.join(pid, participant)

      # Verify participant was added
      {:ok, participants} = Room.get_participants(pid)
      assert Enum.any?(participants, &(&1.id == "user2"))
    end

    test "leave/2 removes a participant from the room", %{pid: pid} do
      participant = %Participant{id: "user3", name: "User 3", type: :human}
      :ok = Room.join(pid, participant)
      assert :ok = Room.leave(pid, participant.id)

      # Posting a message after leaving should fail
      assert {:error, :not_allowed} = Room.post_message(pid, participant.id, "Hello?")

      # Verify participant was removed
      {:ok, participants} = Room.get_participants(pid)
      refute Enum.any?(participants, &(&1.id == "user3"))
    end

    test "get_messages/1 returns messages in correct order", %{pid: pid} do
      participant = %Participant{id: "user4", name: "User 4", type: :human}
      :ok = Room.join(pid, participant)

      {:ok, _} = Room.post_message(pid, "user4", "Message 1")
      {:ok, _} = Room.post_message(pid, "user4", "Message 2")
      {:ok, _} = Room.post_message(pid, "user4", "Message 3")

      # Test chronological order (default)
      {:ok, messages} = Room.get_messages(pid)
      assert Enum.map(messages, & &1.content) == ["Message 1", "Message 2", "Message 3"]

      # Test reverse chronological order
      {:ok, messages} = Room.get_messages(pid, order: :reverse_chronological)
      assert Enum.map(messages, & &1.content) == ["Message 3", "Message 2", "Message 1"]
    end

    test "get_participants/1 returns all participants", %{pid: pid} do
      participants = [
        %Participant{id: "user5", name: "User 5", type: :human},
        %Participant{id: "user6", name: "User 6", type: :human},
        %Participant{id: "agent1", name: "Agent 1", type: :agent}
      ]

      Enum.each(participants, &Room.join(pid, &1))

      {:ok, room_participants} = Room.get_participants(pid)
      assert length(room_participants) == 3
      assert Enum.all?(participants, &Enum.member?(room_participants, &1))
    end
  end

  describe "Room with RoundRobin strategy" do
    setup %{room_id: room_id} do
      Logger.configure(level: :debug)
      # Create a new room with RoundRobin strategy
      {:ok, pid} = Room.start_link(room_id, strategy: Strategy.RoundRobin)
      %{pid: pid}
    end

    test "enforces turn order for non-human participants", %{pid: pid} do
      human = %Participant{id: "human1", name: "Human 1", type: :human}
      agent1 = %Participant{id: "agent1", name: "Agent 1", type: :agent}
      agent2 = %Participant{id: "agent2", name: "Agent 2", type: :agent}

      :ok = Room.join(pid, human)
      :ok = Room.join(pid, agent1)
      :ok = Room.join(pid, agent2)

      # Human can always post
      assert {:ok, _} = Room.post_message(pid, "human1", "Human message")

      # First agent can post
      assert {:ok, _} = Room.post_message(pid, "agent1", "Agent 1 message")

      # Second agent's turn
      assert {:error, :not_allowed} = Room.post_message(pid, "agent1", "Out of turn")
      assert {:ok, _} = Room.post_message(pid, "agent2", "Agent 2 message")

      # Back to first agent
      assert {:ok, _} = Room.post_message(pid, "agent1", "Agent 1 again")

      # Test turn reset when all agents have posted
      assert {:ok, _} = Room.post_message(pid, "agent2", "Agent 2 again")
      assert {:ok, _} = Room.post_message(pid, "agent1", "New round")
    end

    test "handles agent leaving during their turn", %{pid: pid} do
      agent1 = %Participant{id: "agent1", name: "Agent 1", type: :agent}
      agent2 = %Participant{id: "agent2", name: "Agent 2", type: :agent}

      :ok = Room.join(pid, agent1)
      :ok = Room.join(pid, agent2)

      assert {:ok, _} = Room.post_message(pid, "agent1", "Agent 1 message")
      :ok = Room.leave(pid, "agent2")

      # Agent 1 should be able to post again as it's the only agent left
      assert {:ok, _} = Room.post_message(pid, "agent1", "Agent 1 again")
    end
  end

  describe "Room persistence" do
    test "loads existing room on start_link", %{room_id: room_id} do
      # Create and populate a room
      {:ok, pid1} = Room.start_link(room_id)
      :ok = Room.join(pid1, %Participant{id: "user1", name: "User 1", type: :human})
      {:ok, _} = Room.post_message(pid1, "user1", "Persistent message")

      # Stop the room process
      GenServer.stop(pid1)

      # Start a new process for the same room
      {:ok, pid2} = Room.start_link(room_id)

      # Check if the room state was persisted
      {:ok, messages} = Room.get_messages(pid2)
      assert length(messages) == 1
      assert hd(messages).content == "Persistent message"

      {:ok, participants} = Room.get_participants(pid2)
      assert length(participants) == 1
      assert hd(participants).id == "user1"
    end
  end
end
