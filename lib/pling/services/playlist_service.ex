defmodule Pling.Services.PlaylistService do
  alias Jason

  def playlist_paths do
    %{
      "50s" => Path.join(:code.priv_dir(:pling), "static/lists/50s.json"),
      "60s" => Path.join(:code.priv_dir(:pling), "static/lists/60s.json"),
      "70s" => Path.join(:code.priv_dir(:pling), "static/lists/70s.json"),
      "80s" => Path.join(:code.priv_dir(:pling), "static/lists/80s.json"),
      "90s" => Path.join(:code.priv_dir(:pling), "static/lists/90s.json")
    }
  end

  def load_playlists do
    playlist_paths()
    |> Enum.map(fn {decade, path} ->
      {decade, path |> File.read!() |> Jason.decode!()}
    end)
    |> Enum.into(%{})
  end

  def get_tracks(playlists, "mix"), do: playlists |> Map.values() |> List.flatten()
  def get_tracks(playlists, decade), do: Map.get(playlists, decade, [])

  def random_track(tracks), do: Enum.random(tracks)

  def update_track(state) do
    track =
      state.playlists
      |> get_tracks(state.selection.playlist)
      |> random_track()

    %{state | selection: %{playlist: state.selection.playlist, track: track}}
  end

  def set_playlist(state, playlist) do
    %{state | selection: %{playlist: playlist, track: nil}}
    |> update_track()
    |> Map.merge(%{is_playing: false, countdown: nil})
  end

  def start_playback(state) do
    state
    |> update_track()
    |> Map.merge(%{
      is_playing: true,
      countdown: state.spotify_track_duration
    })
  end

  def stop_playback(state) do
    Map.merge(state, %{is_playing: false, countdown: nil})
  end
end
