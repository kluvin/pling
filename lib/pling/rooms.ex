defmodule Pling.Rooms do
  @moduledoc """
  The Rooms context coordinates room-related operations through specialized subcontexts.
  """

  alias Pling.Rooms.{RoomManagement, Presence, Playback, Room}
  require Logger

  # Room State Operations
  defdelegate get_state(room_code), to: Room.Impl

  @doc """
  Updates a score by the given amount.
  """
  defdelegate update_score(room_code, identifier, amount), to: Room.Impl

  # Delegate to Playback context
  defdelegate start_playback(room_code), to: Playback
  defdelegate stop_playback(room_code), to: Playback
  defdelegate next_track(room_code), to: Playback
  defdelegate set_playlist(room_code, playlist), to: Playback
  defdelegate handle_track_timeout(room_code), to: Playback
  defdelegate handle_tick(room_code), to: Playback

  # Delegate to RoomManagement context
  defdelegate monitor_liveview(room_code, pid), to: RoomManagement
  defdelegate handle_liveview_down(room_code, pid, reason), to: RoomManagement
  defdelegate join_room(room_code, user_id, pid, game_mode \\ "vs"), to: RoomManagement

  defdelegate update_presence(room_code, user_id), to: Presence
end
