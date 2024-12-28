# JidoChat Ecto Persistence Change Document

## 1. Overview

Add a robust Ecto-based persistence adapter for long-term channel and message storage, with efficient message windowing and caching capabilities.

## 2. Schema Definitions

### 2.1 Channel Schema
```elixir
defmodule JidoChat.Persistence.Ecto.Channel do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  schema "channels" do
    field :name, :string
    field :message_count, :integer, default: 0
    field :metadata, :map, default: %{}
    
    has_many :messages, JidoChat.Persistence.Ecto.Message
    has_many :participants, JidoChat.Persistence.Ecto.Participant

    timestamps()
  end
end
```

### 2.2 Message Schema
```elixir
defmodule JidoChat.Persistence.Ecto.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :content, :map        # Stores message content and type info
    field :participant_id, :string
    field :sequence_no, :integer  # For ordering within channel
    
    belongs_to :channel, JidoChat.Persistence.Ecto.Channel, type: :string

    timestamps()
  end

  # Create index on (channel_id, sequence_no) for efficient windowing
end
```

### 2.3 Participant Schema
```elixir
defmodule JidoChat.Persistence.Ecto.Participant do
  use Ecto.Schema
  import Ecto.Changeset

  schema "participants" do
    field :external_id, :string
    field :name, :string
    field :type, :string
    field :metadata, :map, default: %{}
    
    belongs_to :channel, JidoChat.Persistence.Ecto.Channel, type: :string

    timestamps()
  end
end
```

## 3. Persistence Adapter

### 3.1 Ecto Adapter Implementation
```elixir
defmodule JidoChat.Channel.Persistence.Ecto do
  @behaviour JidoChat.Channel.Persistence
  
  alias JidoChat.Persistence.Ecto.{Channel, Message, Participant}
  alias JidoChat.Repo

  import Ecto.Query

  @default_window_size 50

  defmodule Cache do
    use GenServer
    
    defstruct [:channel_id, :messages, :window_start, :window_size]
  end

  @impl true
  def save(channel_id, %JidoChat.Channel{} = channel) do
    Repo.transaction(fn ->
      with {:ok, db_channel} <- upsert_channel(channel_id, channel),
           :ok <- update_participants(db_channel, channel.participants),
           :ok <- save_new_messages(db_channel, channel.messages) do
        :ok
      end
    end)
  end

  @impl true
  def load(channel_id, opts \\ []) do
    window_size = Keyword.get(opts, :window_size, @default_window_size)
    
    with {:ok, cache} <- get_or_create_cache(channel_id, window_size),
         {:ok, channel} <- load_channel(channel_id),
         {:ok, messages} <- get_windowed_messages(cache) do
      {:ok, %{channel | messages: messages}}
    end
  end

  def load_more_messages(channel_id, before_sequence_no, limit \\ @default_window_size) do
    query =
      from m in Message,
        where: m.channel_id == ^channel_id and m.sequence_no < ^before_sequence_no,
        order_by: [desc: m.sequence_no],
        limit: ^limit

    messages = Repo.all(query)
    update_cache(channel_id, messages)
    {:ok, messages}
  end
end
```

### 3.2 Cache Management
```elixir
defmodule JidoChat.Channel.Persistence.Ecto.Cache do
  use GenServer
  
  def start_link(channel_id, opts \\ []) do
    GenServer.start_link(__MODULE__, channel_id, opts)
  end

  def init(channel_id) do
    {:ok, %{
      channel_id: channel_id,
      messages: %{},  # Map of sequence_no to message
      window_start: 0,
      window_size: 50
    }}
  end

  def handle_call({:get_window, start, size}, _from, state) do
    # Fetch and cache window of messages
  end

  def handle_call({:update_cache, messages}, _from, state) do
    # Update cache with new messages
  end
end
```

## 4. Query Support

### 4.1 Message Queries
```elixir
defmodule JidoChat.Channel.Persistence.Ecto.Queries do
  import Ecto.Query
  
  def messages_window(channel_id, opts \\ []) do
    start_seq = Keyword.get(opts, :start_sequence, 0)
    limit = Keyword.get(opts, :limit, 50)
    
    Message
    |> where([m], m.channel_id == ^channel_id)
    |> where([m], m.sequence_no >= ^start_seq)
    |> order_by([m], asc: m.sequence_no)
    |> limit(^limit)
  end

  def messages_before(channel_id, sequence_no, limit) do
    Message
    |> where([m], m.channel_id == ^channel_id)
    |> where([m], m.sequence_no < ^sequence_no)
    |> order_by([m], desc: m.sequence_no)
    |> limit(^limit)
  end
end
```

## 5. Channel Integration

### 5.1 Channel Module Changes
```elixir
defmodule JidoChat.Channel do
  # Add support for pagination
  def get_messages(channel, opts \\ []) do
    case opts[:before] do
      nil -> 
        # Get current window from cache
        Channel.Persistence.load(channel.id)
      sequence_no -> 
        # Load historical messages
        Channel.Persistence.load_more_messages(channel.id, sequence_no)
    end
  end
end
```

## 6. Implementation Requirements

### 6.1 Database Setup
- Migrations for channels, messages, and participants
- Appropriate indices for efficient querying
- Sequence number generation for messages

### 6.2 Cache Management
- Efficient window tracking
- Cache invalidation strategy
- Memory usage optimization
- Cache synchronization

### 6.3 Performance Optimization
- Batch inserts for messages
- Efficient window queries
- Index optimization
- Cache hit rate monitoring

## 7. Testing Requirements

### 7.1 Functional Testing
- Message persistence
- Window management
- Cache behavior
- Historical loading

### 7.2 Performance Testing
- Large message volume handling
- Cache effectiveness
- Query performance
- Memory usage patterns

### 7.3 Integration Testing
- Channel integration
- Cache synchronization
- Window management
- Error handling

## 8. Migration Support

### 8.1 Data Migration
- Migration from ETS/Memory to Ecto
- Message sequence numbering
- Historical data import
- Participant data transfer

### 8.2 Runtime Migration
- Zero-downtime migration support
- Fallback mechanisms
- State recovery procedures
- Cache warming strategies