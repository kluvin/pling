defmodule Pling.Rooms do
  @moduledoc """
  The Rooms context.
  """

  alias Pling.Rooms.{RoomManagement, Presence, Playback, Scoring, Room}
  require Logger

  defdelegate get_state(room_code), to: Room.Impl

  defdelegate update_score(room_code, identifier, amount), to: Scoring

  defdelegate start_playback(room_code), to: Playback
  defdelegate stop_playback(room_code), to: Playback
  defdelegate next_track(room_code), to: Playback
  defdelegate set_playlist(room_code, playlist), to: Playback
  defdelegate monitor_liveview(room_code, pid), to: RoomManagement
  defdelegate handle_liveview_down(room_code, pid, reason), to: RoomManagement
  defdelegate join_room(room_code, user_id, pid, game_mode \\ "vs"), to: RoomManagement

  defdelegate update_presence(room_code, user_id), to: Presence
end
