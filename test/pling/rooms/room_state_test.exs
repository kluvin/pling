defmodule Pling.Rooms.RoomStateTest do
  use ExUnit.Case, async: true
  alias Pling.Rooms.RoomState
  alias Pling.Playlists.Playlist

  describe "initialize/3" do
    test "creates initial state with required fields" do
      state = RoomState.initialize("room1", "vs", "leader1")

      assert state.room_code == "room1"
      assert state.game_mode == "vs"
      assert state.leader_id == "leader1"
      assert state.playing? == false
      assert state.countdown == nil
      assert state.timer_ref == nil
      assert state.scores == %{}
      assert state.playlists == %{}
      assert state.selection.playlist != nil
      assert state.selection.queue == []
    end

    test "raises error when leader_id is nil" do
      assert_raise RuntimeError, "leader_id must be provided when initializing a room", fn ->
        RoomState.initialize("room1", "vs", nil)
      end
    end
  end

  describe "for_client/1" do
    test "formats state for client consumption" do
      playlist = %Playlist{spotify_id: "test_id", name: "Test Playlist", tracks: []}
      state = %{
        RoomState.initialize("room1", "vs", "leader1") |
        playlists: %{"test_id" => playlist}
      }

      client_state = RoomState.for_client(state)

      assert client_state.playing? == false
      assert client_state.game_mode == "vs"
      assert client_state.leader_id == "leader1"
      assert client_state.playlists["test_id"] == %{
        spotify_id: "test_id",
        name: "Test Playlist"
      }
      refute Map.has_key?(client_state, :timer_ref)
    end
  end
end
