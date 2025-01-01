defmodule Pling.RoomsTest do
  use ExUnit.Case
  use Pling.RoomCase

  describe "room lifecycle" do
    test "creates and joins a room" do
      %{room_code: _, user_id: user_id, state: state} = create_test_room()

      assert state.leader_id == user_id
      assert state.game_mode == "vs"
    end

    test "multiple users can join a room" do
      %{room_code: room_code, user_id: user_id1} = create_test_room()
      %{user_id: user_id2, state: state2} = join_room(room_code)

      # First user remains leader
      assert state2.leader_id == user_id1
      # Second user is not leader
      refute state2.leader_id == user_id2
    end
  end

  describe "scoring" do
    test "increments player score" do
      %{room_code: room_code, user_id: user_id} = create_test_room()

      Rooms.increment_player_score(room_code, user_id)
      state = Rooms.get_state(room_code)

      assert state.player_scores[user_id] == 1
    end

    test "updates team counter" do
      %{room_code: room_code} = create_test_room()

      Rooms.update_counter(:increment, room_code, "red")
      state = Rooms.get_state(room_code)

      assert state.red_count == 1
    end
  end

  describe "playback" do
    test "starts and stops playback" do
      %{room_code: room_code} = create_test_room()

      {:ok, state1} = Rooms.play(room_code)
      assert state1.playing? == true

      {:ok, state2} = Rooms.pause(room_code)
      assert state2.playing? == false
    end
  end
end
