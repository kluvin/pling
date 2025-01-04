defmodule Pling.Rooms do
  @moduledoc """
  The Room API module - provides the public interface for room operations.
  """

  alias Pling.Rooms.Room.Server
  require Logger

  def get_state(room_code) do
    GenServer.call(via_tuple(room_code), :get_state)
  end

  def update_score(room_code, identifier, amount) do
    GenServer.cast(via_tuple(room_code), {:update_score, identifier, amount})
  end

  def play(room_code) do
    GenServer.call(via_tuple(room_code), :play)
  end

  def pause(room_code) do
    GenServer.call(via_tuple(room_code), :pause)
  end

  def update_track(room_code) do
    GenServer.call(via_tuple(room_code), :update_track)
  end

  def set_playlist(room_code, playlist) do
    GenServer.call(via_tuple(room_code), {:set_playlist, playlist})
  end

  def process_tick(room_code) do
    GenServer.cast(via_tuple(room_code), :process_tick)
  end

  def join_room(room_code, user_id, pid, game_mode, playlist \\ nil) do
    Logger.metadata(room_code: room_code, user_id: user_id)
    Logger.info("Joining room", event: :room_join, game_mode: game_mode)

    case get_or_create_room(room_code, game_mode, user_id, playlist) do
      {:ok, room_pid} ->
        case GenServer.call(room_pid, {:monitor_liveview, pid}) do
          :ok ->
            Logger.info("Room joined successfully", event: :room_join_success)
            {:ok, get_state(room_code)}

          error ->
            Logger.error("Failed to join room", event: :room_join_error, error: inspect(error))
            error
        end

      error ->
        Logger.error("Failed to create room", event: :room_create_error, error: inspect(error))
        error
    end
  end

  defp get_or_create_room(room_code, game_mode, leader_id, playlist) do
    case get_room_pid(room_code) do
      {:ok, pid} ->
        Logger.debug("Using existing room", event: :room_found)
        {:ok, pid}

      :error ->
        Logger.info("Creating new room", event: :room_create)

        DynamicSupervisor.start_child(
          Pling.Rooms.RoomSupervisor,
          {Server, {room_code, game_mode, leader_id, playlist}}
        )
    end
  end

  defp via_tuple(room_code) do
    {:via, Registry, {Pling.Rooms.ServerRegistry, room_code}}
  end

  @doc """
  Gets the PID of a room by its room code.
  Returns {:ok, pid} if the room exists, :error otherwise.
  """
  def get_room_pid(room_code) do
    case Registry.lookup(Pling.Rooms.ServerRegistry, room_code) do
      [{pid, _}] -> {:ok, pid}
      [] -> :error
    end
  end
end
