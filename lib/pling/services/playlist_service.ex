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

  # Keep these as pure functions that return the new state
  def update_track(state, playlist \\ nil) do
    playlist = playlist || state.selection.playlist
    track = random_track(get_tracks(state.playlists, playlist))
    %{state | selection: %{playlist: playlist, track: track}}
  end

  def set_playlist(state, playlist) do
    state
    |> update_track(playlist)
    |> Map.merge(%{is_playing: false, countdown: nil})
  end
end
