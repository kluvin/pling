defmodule Pling.Playlists.MusicLibraryTest do
  use Pling.DataCase, async: true
  alias Pling.Playlists.{MusicLibrary, Playlist, Track}

  describe "get_or_fetch_playlist/1" do
    test "returns existing playlist when it exists" do
      playlist = %Playlist{
        spotify_id: "existing_id",
        name: "Test Playlist",
        owner: "test_owner",
        image_url: "http://example.com/image.jpg",
        official: false
      }

      {:ok, _} = Repo.insert(playlist)

      assert {:ok, :exists, fetched_playlist} = MusicLibrary.get_or_fetch_playlist("existing_id")
      assert fetched_playlist.spotify_id == "existing_id"
      assert fetched_playlist.name == "Test Playlist"
    end

    test "fetches new playlist from Spotify when it doesn't exist" do
      playlist_id = "new_playlist_id"

      # Mock the Spotify.stream_playlist behavior by sending messages directly
      test_pid = self()

      # Mock the Spotify.stream_playlist function
      :meck.new(Pling.Services.Spotify, [:passthrough])

      :meck.expect(Pling.Services.Spotify, :stream_playlist, fn ^playlist_id, callback ->
        # Simulate playlist info
        callback.(%{
          "playlist_info" => %{
            "name" => "New Playlist",
            "owner" => "spotify_user",
            "images" => [%{"url" => "http://example.com/new.jpg"}]
          }
        })

        # Simulate track data
        callback.(%{
          "track" => %{
            "uri" => "spotify:track:123",
            "name" => "Test Track",
            "artists" => [%{"name" => "Test Artist"}],
            "popularity" => 80,
            "album" => %{"name" => "Test Album"}
          }
        })

        :ok
      end)

      try do
        assert {:ok, :first_track_saved, playlist} =
                 MusicLibrary.get_or_fetch_playlist(playlist_id)

        assert playlist.spotify_id == playlist_id
        assert playlist.name == "New Playlist"

        # Verify track was saved
        track = Repo.get_by(Track, uri: "spotify:track:123")
        assert track.title == "Test Track"
      after
        :meck.unload(Pling.Services.Spotify)
      end
    end

    test "handles errors during playlist fetch" do
      playlist_id = "error_playlist_id"

      # Mock the Spotify service with an error
      :meck.new(Pling.Services.Spotify, [:passthrough])

      :meck.expect(Pling.Services.Spotify, :stream_playlist, fn ^playlist_id, _callback ->
        {:error, "API Error"}
      end)

      try do
        assert {:error, "API Error"} = MusicLibrary.get_or_fetch_playlist(playlist_id)
      after
        :meck.unload(Pling.Services.Spotify)
      end
    end
  end
end
