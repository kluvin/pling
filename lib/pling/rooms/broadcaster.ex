defmodule Pling.Rooms.Broadcaster do
  @moduledoc """
  Handles broadcasting room events through PubSub
  """

  def broadcast_track_load(room_code, track) do
    PlingWeb.Endpoint.broadcast(
      "room:#{room_code}",
      "spotify:load_track",
      %{track: track}
    )
  end

  def broadcast_bell(room_code) do
    PlingWeb.Endpoint.broadcast(
      "room:#{room_code}",
      "ring_bell",
      %{}
    )
  end

  def broadcast_state_transition(room_code, state) do
    PlingWeb.Endpoint.broadcast(
      "room:#{room_code}",
      "state_update",
      %{state: state}
    )
  end

  def broadcast_toggle_play(room_code, from_pid \\ self()) do
    PlingWeb.Endpoint.broadcast_from(
      from_pid,
      "room:#{room_code}",
      "spotify:toggle_play",
      %{}
    )
  end
end
