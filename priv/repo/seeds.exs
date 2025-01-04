alias Pling.Repo
alias Pling.Playlists.{MusicLibrary, Playlist}

playlists = %{
  "50s" => "6ZSeHvrhmEH4erjxudpULB"
}

# Import each playlist
Enum.each(playlists, fn {decade, spotify_id} ->
  # Skip if playlist already exists
  unless Repo.get(Playlist, spotify_id) do
    case MusicLibrary.get_or_fetch_playlist(spotify_id) do
      {:error, reason} ->
        IO.puts("Failed to import #{decade} playlist (#{spotify_id}): #{inspect(reason)}")

      {:ok, _status, playlist} ->
        IO.puts("Imported #{decade} playlist: #{playlist.name}")
    end
  end
end)
