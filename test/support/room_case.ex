defmodule Pling.RoomCase do
  @moduledoc """
  This module defines common test helpers for room-related tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Pling.Rooms
      alias Pling.Repo
      import Pling.RoomCase
    end
  end

  setup tags do
    # Set up database connection ownership for the test process
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Pling.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    :ok
  end

  @doc """
  Creates a room for testing with default parameters.
  """
  def create_test_room(opts \\ []) do
    room_code = Keyword.get(opts, :room_code, "TEST#{System.unique_integer()}")
    user_id = Keyword.get(opts, :user_id, "user_#{System.unique_integer()}")
    game_mode = Keyword.get(opts, :game_mode, "vs")

    {:ok, state} = Pling.Rooms.join_room(room_code, user_id, self(), game_mode)
    %{room_code: room_code, user_id: user_id, state: state}
  end

  @doc """
  Simulates a user joining a room.
  """
  def join_room(room_code, user_id \\ nil) do
    user_id = user_id || "user_#{System.unique_integer()}"
    {:ok, state} = Pling.Rooms.join_room(room_code, user_id, self())
    %{user_id: user_id, state: state}
  end

  @doc """
  Waits for a specific condition to be true in the room state.
  Useful for testing asynchronous operations.
  """
  def wait_for_condition(room_code, condition, timeout \\ 1000) do
    start = System.monotonic_time(:millisecond)
    wait_for_condition(room_code, condition, timeout, start)
  end

  defp wait_for_condition(room_code, condition, timeout, start) do
    state = Pling.Rooms.get_state(room_code)

    cond do
      condition.(state) ->
        {:ok, state}

      System.monotonic_time(:millisecond) - start > timeout ->
        {:error, :timeout}

      true ->
        Process.sleep(10)
        wait_for_condition(room_code, condition, timeout, start)
    end
  end
end
