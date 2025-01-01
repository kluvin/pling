defmodule Pling.Rooms.PlaybackTest do
  use ExUnit.Case
  use Pling.RoomCase

  setup do
    # Set up a test playlist in the database
    {:ok, playlist} =
      Pling.Repo.insert(%Pling.Rooms.Playlist{
        decade: "test_decade",
        name: "Test Playlist"
      })

    # Add some test tracks
    {:ok, track1} =
      Pling.Repo.insert(%Pling.Rooms.Track{
        playlist_id: playlist.id,
        title: "Test Track 1",
        artist: "Test Artist",
        uri: "spotify:track:test1"
      })

    {:ok, track2} =
      Pling.Repo.insert(%Pling.Rooms.Track{
        playlist_id: playlist.id,
        title: "Test Track 2",
        artist: "Test Artist",
        uri: "spotify:track:test2"
      })

    %{playlist: playlist, tracks: [track1, track2]}
  end

  describe "playback management" do
    test "handles track timeouts", %{playlist: playlist} do
      %{room_code: room_code} = create_test_room()

      Rooms.set_playlist(room_code, playlist.decade)
      {:ok, _} = Rooms.play(room_code)

      state = Rooms.handle_track_timeout(room_code)
      assert state.playing? == false
    end

    test "selects tracks from playlist", %{playlist: playlist, tracks: [track1, track2]} do
      %{room_code: room_code} = create_test_room()

      Rooms.set_playlist(room_code, playlist.decade)
      {:ok, state} = Rooms.play(room_code)

      # Should select a track from our playlist
      assert state.selection.track.id in [track1.id, track2.id]
      assert state.selection.playlist == playlist.decade
      assert state.playing? == true
    end
  end
end
