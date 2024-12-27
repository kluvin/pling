defmodule Pling.Rooms.TeamScoring do
  @moduledoc """
  Handles team scoring operations and state management.
  """
  require Logger
  alias Pling.Rooms.{Broadcaster, RoomState}

  def increment(state, "red") do
    new_state = %{state | red_count: state.red_count + 1}
    Broadcaster.broadcast_state_transition(state.room_code, RoomState.for_client(new_state))
    new_state
  end

  def increment(state, "blue") do
    new_state = %{state | blue_count: state.blue_count + 1}
    Broadcaster.broadcast_state_transition(state.room_code, RoomState.for_client(new_state))
    new_state
  end
  def increment(state, _), do: state

  def decrement(state, "red") do
    new_state = %{state | red_count: max(0, state.red_count - 1)}
    Broadcaster.broadcast_state_transition(state.room_code, RoomState.for_client(new_state))
    new_state
  end

  def decrement(state, "blue") do
    new_state = %{state | blue_count: max(0, state.blue_count - 1)}
    Broadcaster.broadcast_state_transition(state.room_code, RoomState.for_client(new_state))
    new_state
  end
  def decrement(state, _), do: state
end
