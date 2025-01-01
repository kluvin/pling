defmodule Pling.Rooms do
  @moduledoc """
  The Room API module - provides the public interface for room operations.
  """

  alias Pling.Rooms.Room.Server

  def get_state(room_code) do
    GenServer.call(via_tuple(room_code), :get_state)
  end

  def update_score(room_code, identifier, amount) do
    GenServer.cast(via_tuple(room_code), {:update_score, identifier, amount})
  end

  def play(room_code) do
    GenServer.call(via_tuple(room_code), :play)
  end

  def pause(room_code) do
    GenServer.call(via_tuple(room_code), :pause)
  end

  def update_track(room_code) do
    GenServer.call(via_tuple(room_code), :update_track)
  end

  def set_playlist(room_code, playlist) do
    GenServer.call(via_tuple(room_code), {:set_playlist, playlist})
  end

  def process_tick(room_code) do
    GenServer.cast(via_tuple(room_code), :process_tick)
  end

  def join_room(room_code, user_id, pid, game_mode \\ "vs") do
    if get_room_pid(room_code) == :error do
      DynamicSupervisor.start_child(
        Pling.Rooms.RoomSupervisor,
        {Server, {room_code, game_mode, user_id}}
      )
    end

    GenServer.call(via_tuple(room_code), {:monitor_liveview, pid})
    {users, leader?} = Pling.Rooms.Presence.initialize_presence(room_code, user_id)
    current_state = get_state(room_code)
    {:ok, Map.merge(current_state, %{users: users, leader?: leader?})}
  end

  defp via_tuple(room_code) do
    {:via, Registry, {Pling.Rooms.ServerRegistry, room_code}}
  end

  defp get_room_pid(room_code) do
    case Registry.lookup(Pling.Rooms.ServerRegistry, room_code) do
      [{pid, _}] -> {:ok, pid}
      [] -> :error
    end
  end
end
