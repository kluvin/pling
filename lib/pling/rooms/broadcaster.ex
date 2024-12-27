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

  def broadcast_playback_stop(room_code) do
    PlingWeb.Endpoint.broadcast(
      "pling:room:#{room_code}",
      "state_update",
      %{state: Pling.Rooms.get_state(room_code)}
    )
  end

  def broadcast_bell(room_code) do
    PlingWeb.Endpoint.broadcast(
      "pling:room:#{room_code}",
      "ring_bell",
      %{}
    )
  end

  def broadcast_state_transition(room_code, state) do
    PlingWeb.Endpoint.broadcast(
      "pling:room:#{room_code}",
      "state_update",
      %{state: state}
    )
  end
end
