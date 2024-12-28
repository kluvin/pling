defmodule Pling.Rooms.Broadcaster do
  @moduledoc """
  Handles broadcasting room events through PubSub
  """

  def broadcast_track_load(room_code, track) do
    PlingWeb.Endpoint.broadcast(
      "pling:room:#{room_code}",
      "spotify:load_track",
      %{track: track}
    )
  end

  def broadcast_bell(room_code, pid \\ self()) do
    start_time = System.system_time(:millisecond) + 500 # Add 500ms buffer

    PlingWeb.Endpoint.broadcast(
      "pling:room:#{room_code}",
      "ring_bell",
      %{start_time: start_time}
    )
  end

  def broadcast_state_transition(room_code, state) do
    PlingWeb.Endpoint.broadcast(
      "pling:room:#{room_code}",
      "state_update",
      %{state: state}
    )
  end

  def broadcast_toggle_play(room_code, pid \\ self()) do
    start_time = System.system_time(:millisecond) + 500 # Add 500ms buffer

    PlingWeb.Endpoint.broadcast(
      "pling:room:#{room_code}",
      "spotify:toggle_play",
      %{start_time: start_time}
    )
  end
end
