alias Pling.Repo
alias Pling.Rooms.{Playlist, Track}

# Define the decades and their corresponding JSON files
playlists = %{
  "50s" => Path.join(:code.priv_dir(:pling), "static/lists/50s.json"),
  "60s" => Path.join(:code.priv_dir(:pling), "static/lists/60s.json"),
  "70s" => Path.join(:code.priv_dir(:pling), "static/lists/70s.json"),
  "80s" => Path.join(:code.priv_dir(:pling), "static/lists/80s.json"),
  "90s" => Path.join(:code.priv_dir(:pling), "static/lists/90s.json")
}

# Import each playlist
Enum.each(playlists, fn {decade, path} ->
  # Skip if playlist already exists
  unless Repo.get_by(Playlist, decade: decade) do
    playlist = Repo.insert!(%Playlist{name: "#{decade} Hits", decade: decade})

    uris = path |> File.read!() |> Jason.decode!()

    Enum.each(uris, fn uri ->
      %Track{}
      |> Track.changeset(%{uri: uri, playlist_id: playlist.id})
      |> Repo.insert!()
    end)

    IO.puts("Imported #{decade} playlist with #{length(uris)} tracks")
  end
end)
