defmodule Pling.Rooms.RoomManagement do
  @moduledoc """
  Handles room lifecycle operations (creation, termination, monitoring).
  """

  alias Pling.Rooms.{Room, Presence}
  alias Room.Impl
  require Logger

  @doc """
  Joins a room, starting it if necessary, and initializes presence.
  Returns the complete state including presence information.
  """
  def join_room(room_code, user_id, pid, game_mode \\ "vs") do
    Logger.metadata(room_code: room_code, user_id: user_id)
    Logger.info("User joining room", event: :room_join)

    server_pid =
      case get_room_pid(room_code) do
        {:ok, pid} ->
          pid

        :error ->
          {:ok, pid} =
            start_room(room_code, game_mode, user_id)

          pid
      end

    send(server_pid, {:monitor_liveview, pid})

    {users, leader?} = Presence.initialize_presence(room_code, user_id)
    current_state = Impl.get_state(room_code)

    {:ok, Map.merge(current_state, %{users: users, leader?: leader?})}
  end

  @doc """
  Starts a new room with the given code.
  """
  def start_room(room_code, game_mode \\ "vs", leader_id \\ nil) do
    Logger.metadata(room_code: room_code)
    Logger.info("Starting room", event: :room_start)

    DynamicSupervisor.start_child(
      Pling.RoomSupervisor,
      {Room.Server, {room_code, game_mode, leader_id}}
    )
  end

  @doc """
  Returns the pid for a room if it exists.
  """
  def get_room_pid(room_code) do
    case Registry.lookup(Pling.Rooms.ServerRegistry, room_code) do
      [{pid, _}] ->
        Logger.debug("Found existing room",
          event: :room_lookup,
          room_code: room_code,
          pid: inspect(pid)
        )

        {:ok, pid}

      [] ->
        Logger.debug("Room not found", event: :room_lookup, room_code: room_code)
        :error
    end
  end

  @doc """
  Terminates a room if it exists.
  """
  def terminate_room(room_code) do
    case Registry.lookup(Pling.Rooms.ServerRegistry, room_code) do
      [{pid, _}] ->
        Logger.info("Terminating room",
          event: :room_terminate,
          room_code: room_code,
          pid: inspect(pid)
        )

        DynamicSupervisor.terminate_child(Pling.RoomSupervisor, pid)
        :ok

      [] ->
        Logger.debug("Cannot terminate: room not found",
          event: :room_terminate,
          room_code: room_code
        )

        :error
    end
  end

  @doc """
  Monitors a LiveView process for a room.
  """
  def monitor_liveview(room_code, pid) do
    Logger.info("LiveView connected",
      event: :liveview_monitor,
      pid: inspect(pid),
      connection_count: count_clients(room_code) + 1
    )

    Room.Impl.monitor_liveview(room_code, pid)
  end

  @doc """
  Handles LiveView process termination.
  """
  def handle_liveview_down(room_code, pid, reason) do
    client_count = count_clients(room_code)

    Logger.info("LiveView disconnected",
      event: :liveview_down,
      pid: inspect(pid),
      reason: reason,
      connection_count: client_count - 1
    )

    if client_count <= 1 do
      Logger.info("No more connections, terminating", event: :server_terminate)
      terminate_room(room_code)
    end
  end

  @doc """
  Increments a player's score in the given room.
  """
  def increment_player_score(room_code, user_id, amount \\ 1) do
    with {:ok, pid} <- get_room_pid(room_code) do
      GenServer.call(pid, {:increment_score, user_id, amount})
    end
  end

  @doc """
  Decrements a player's score in the given room.
  """
  def decrement_player_score(room_code, user_id, amount \\ 1) do
    with {:ok, pid} <- get_room_pid(room_code) do
      GenServer.call(pid, {:decrement_score, user_id, amount})
    end
  end

  # Private helper to count clients
  defp count_clients(room_code) do
    Registry.lookup(Pling.Rooms.ClientRegistry, room_code)
    |> length()
  end
end
