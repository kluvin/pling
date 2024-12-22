defmodule Pling.Playlists do
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
end
