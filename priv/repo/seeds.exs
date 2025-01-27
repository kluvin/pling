alias Pling.Repo
alias Pling.Playlists.{MusicLibrary, Playlist}

playlists = [
  "6ZSeHvrhmEH4erjxudpULB",
  "4mUy5wCcZi5Nq6azLEM9ik",
  "3wvTJnQoBgxZe99WDF1zcN",
  "4DIYG1WrBI9jRJiul9vmxj",
  "24wKd8i8ANGZhMZq4U7Eaj",
  "50nqzehFR03d6ULmqTQFn4"
]


# Import each playlist
Enum.each(playlists, fn spotify_id ->
  # Skip if playlist already exists
  unless Repo.get(Playlist, spotify_id) do
    case MusicLibrary.get_or_fetch_playlist(spotify_id) do
      {:error, reason} ->
        IO.puts("Failed to import playlist: (#{spotify_id}): #{inspect(reason)}")

      {:ok, _status, playlist} ->
        playlist
        |> Playlist.changeset(%{official: true})
        |> Repo.update!()
        IO.puts("Imported playlist: #{playlist.name}")
    end
  end
end)
