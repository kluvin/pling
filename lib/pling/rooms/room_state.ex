defmodule Pling.Rooms.RoomState do
  @moduledoc """
  Manages the core room state and provides client-facing state transformations.
  """

  @default_track_duration 30

  def initialize(room_code, game_mode \\ "vs") do
    %{
      red_count: 0,
      blue_count: 0,
      is_playing: false,
      countdown: nil,
      timer_ref: nil,
      timer_threshold: 10,
      spotify_track_duration: @default_track_duration,
      selection: %{playlist: "90s", track: nil},
      playlists: nil,
      room_code: room_code,
      game_mode: game_mode
    }
  end

  def for_client(state) do
    %{
      red_count: state.red_count,
      blue_count: state.blue_count,
      is_playing: state.is_playing,
      countdown: state.countdown,
      timer_threshold: state.timer_threshold,
      selection: Map.take(state.selection, [:track, :playlist]),
      playlists: state.playlists,
      game_mode: state.game_mode
    }
  end
end
