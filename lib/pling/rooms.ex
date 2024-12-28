defmodule Pling.Rooms do
  @moduledoc """
  The Rooms context coordinates room-related operations through specialized subcontexts.
  """

  alias Pling.Rooms.{RoomManagement, Presence, Playback, RoomServer}
  require Logger

  # Room State Operations
  def get_state(room_code), do: RoomServer.get_state(room_code)

  @doc """
  Increments or decrements a team's counter.
  """
  def update_counter(action, room_code, color) when action in [:increment, :decrement] do
    RoomServer.counter(action, room_code, color)
  end

  # Player Score Operations
  defdelegate increment_player_score(room_code, user_id, amount \\ 1), to: RoomServer
  defdelegate decrement_player_score(room_code, user_id, amount \\ 1), to: RoomServer
  defdelegate add_recent_pling(room_code, user_id), to: RoomServer
  defdelegate clear_recent_plings(room_code), to: RoomServer

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

  @doc """
  Joins a room, starting it if necessary, and initializes presence.
  Returns the complete state including presence information.
  """
  def join_room(room_code, user_id, pid, game_mode \\ "vs") do
    Logger.metadata(room_code: room_code, user_id: user_id)
    Logger.info("User joining room", event: :room_join)

    server_pid =
      case RoomManagement.get_room_pid(room_code) do
        {:ok, pid} -> pid
        :error -> {:ok, pid} =
          RoomManagement.start_room(room_code, game_mode, user_id)
          pid
      end

    send(server_pid, {:monitor_liveview, pid})

    {users, leader?} = Presence.initialize_presence(room_code, user_id)
    current_state = get_state(room_code)

    {:ok, Map.merge(current_state, %{users: users, leader?: leader?})}
  end

  defdelegate update_presence(room_code, user_id), to: Presence
end
