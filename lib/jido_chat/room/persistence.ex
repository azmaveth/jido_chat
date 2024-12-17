defmodule JidoChat.Room.Persistence do
  @callback save(String.t(), JidoChat.Room.t()) :: :ok | {:error, term()}
  @callback load(String.t()) :: {:ok, JidoChat.Room.t()} | {:error, term()}
  @callback delete(String.t()) :: :ok | {:error, term()}

  def save(room_id, room_state) do
    JidoChat.Room.Persistence.ETS.save(room_id, room_state)
  end

  def load(room_id) do
    JidoChat.Room.Persistence.ETS.load(room_id)
  end

  def delete(room_id) do
    JidoChat.Room.Persistence.ETS.delete(room_id)
  end

  def load_or_create(room_id) do
    case load(room_id) do
      {:ok, room} -> {:ok, room}
      {:error, :not_found} -> {:ok, %JidoChat.Room{id: room_id, name: "Room #{room_id}"}}
    end
  end
end
