defmodule Pling.Rooms.RoomState do
  @moduledoc """
  Defines the core room state structure and provides client-facing state transformations.
  """

  @default_track_duration 30
  @default_playlist_id "6ZSeHvrhmEH4erjxudpULB"

  def initialize(room_code, game_mode \\ "vs", leader_id \\ nil) do
    if leader_id == nil do
      raise "leader_id must be provided when initializing a room"
    end

    %{
      scores: %{},
      playing?: false,
      countdown: nil,
      timer_ref: nil,
      timer_threshold: 10,
      spotify_track_duration: @default_track_duration,
      playlists: %{},
      room_code: room_code,
      game_mode: game_mode,
      leader_id: leader_id,
      recent_plings: [],
      selection: %{
        playlist: @default_playlist_id,
        track: nil
      }
    }
  end

  def for_client(state) do
    %{
      playing?: state.playing?,
      countdown: state.countdown,
      timer_threshold: state.timer_threshold,
      playlists: format_playlists(state.playlists),
      game_mode: state.game_mode,
      scores: state.scores,
      leader_id: state.leader_id,
      recent_plings: state.recent_plings,
      selection: state.selection
    }
  end

  defp format_playlist(playlist), do: Map.take(playlist, [:spotify_id, :name])

  defp format_playlists(playlists) when is_map(playlists) do
    playlists
    |> Map.new(fn {spotify_id, playlist} ->
      {spotify_id, format_playlist(playlist)}
    end)
  end
end
