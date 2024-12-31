defmodule Pling.Rooms.Scoring do
  @moduledoc """
  Handles scoring operations using a unified map-based scoring system.
  Scores are stored in state.scores where the key can be either:
  - A team identifier (e.g. "red", "blue")
  - A user_id for free-for-all mode
  """
  require Logger
  alias Pling.Rooms.{Broadcaster, RoomState, PlaybackManager, Room}

  def update(state, identifier, amount) do
    current_score = Map.get(state.scores, identifier, 0)
    new_score = max(0, current_score + amount)
    new_state = %{state | scores: Map.put(state.scores, identifier, new_score)}

    # Only update track in team mode
    new_state =
      if state.game_mode == "vs", do: PlaybackManager.update_track(new_state), else: new_state

    Broadcaster.broadcast_state_transition(state.room_code, RoomState.for_client(new_state))
    new_state
  end

  def get_score(state, identifier) do
    Map.get(state.scores, identifier, 0)
  end

  def update_score(room_code, identifier, amount) do
    state = Room.Impl.get_state(room_code)
    new_state = update(state, identifier, amount)
    Room.Impl.update_state(room_code, new_state)
    {:ok, new_state}
  end
end
