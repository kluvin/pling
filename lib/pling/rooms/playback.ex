defmodule Pling.Rooms.Playback do
  @moduledoc """
  Manages playback state for rooms.
  """
  alias Pling.Rooms.{RoomServer, PlaybackManager}

  def start_playback(room_code) do
    with state <- RoomServer.get_state(room_code),
         new_state <- PlaybackManager.start_playback(state) do
      RoomServer.update_state(room_code, new_state)
    end
  end

  def stop_playback(room_code) do
    with state <- RoomServer.get_state(room_code),
         new_state <- PlaybackManager.stop_playback(state) do
      RoomServer.update_state(room_code, new_state)
    end
  end

  def handle_tick(room_code) do
    with state <- RoomServer.get_state(room_code),
         new_state <- PlaybackManager.tick(state) do
      RoomServer.update_state(room_code, new_state)
    end
  end

  def handle_track_timeout(room_code) do
    with state <- RoomServer.get_state(room_code),
         new_state <- PlaybackManager.handle_track_timeout(state) do
      RoomServer.update_state(room_code, new_state)
    end
  end

  def set_playlist(room_code, playlist) do
    with state <- RoomServer.get_state(room_code),
         new_state <- PlaybackManager.change_playlist(state, playlist) do
      RoomServer.update_state(room_code, new_state)
    end
  end

  def next_track(room_code) do
    with state <- RoomServer.get_state(room_code),
         new_state <- PlaybackManager.update_track(state) do
      RoomServer.update_state(room_code, new_state)
    end
  end
end
