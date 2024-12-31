defmodule Pling.Rooms.Room.Impl do
  alias Pling.Rooms.{RoomState, PlaybackManager, Scoring}
  alias Pling.Rooms

  # Client API
  def start_link({room_code, game_mode, leader_id}) do
    GenServer.start_link(Pling.Rooms.Room.Server, {room_code, game_mode, leader_id},
      name: via_tuple(room_code)
    )
  end

  def get_state(room_code) do
    GenServer.call(via_tuple(room_code), :get_state)
  end

  def update_score(room_code, identifier, amount) do
    GenServer.call(via_tuple(room_code), {:update_score, identifier, amount})
  end

  def monitor_liveview(room_code, pid) do
    GenServer.call(via_tuple(room_code), {:monitor_liveview, pid})
  end

  def update_state(room_code, new_state) do
    GenServer.call(via_tuple(room_code), {:update_state, new_state})
  end

  def stop_playback(state), do: PlaybackManager.stop_playback(state)
  def start_playback(state), do: PlaybackManager.start_playback(state)

  # Server Implementation
  def initialize(room_code, game_mode, leader_id) do
    room_code
    |> RoomState.initialize(game_mode, leader_id)
    |> PlaybackManager.initialize_playlists()
    |> PlaybackManager.update_track()
  end

  def handle_score_update(state, identifier, amount),
    do: Scoring.update(state, identifier, amount)

  def handle_tick(state), do: PlaybackManager.tick(state)

  def handle_liveview_down(room_code, pid, reason),
    do: Rooms.handle_liveview_down(room_code, pid, reason)

  def for_client(state), do: RoomState.for_client(state)

  def via_tuple(room_code) do
    {:via, Registry, {Pling.Rooms.ServerRegistry, room_code}}
  end
end
