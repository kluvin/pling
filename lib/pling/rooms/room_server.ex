defmodule Pling.Rooms.RoomServer do
  use GenServer
  alias Pling.Rooms.{RoomState, PlaybackManager, TeamScoring}
  alias Pling.Rooms
  require Logger

  # Client API
  def start_link({room_code, game_mode}) do
    GenServer.start_link(__MODULE__, {room_code, game_mode}, name: via_tuple(room_code))
  end

  def get_state(room_code) do
    GenServer.call(via_tuple(room_code), :get_state)
  end

  def counter(:increment, room_code, color),
    do: GenServer.call(via_tuple(room_code), {:increment_counter, color})

  def counter(:decrement, room_code, color),
    do: GenServer.call(via_tuple(room_code), {:decrement_counter, color})

  # Playback-specific API
  def start_playback(room_code), do: GenServer.call(via_tuple(room_code), :start_playback)
  def stop_playback(room_code), do: GenServer.call(via_tuple(room_code), :stop_playback)

  # Add these new client API functions
  def monitor_liveview(room_code, pid) do
    GenServer.call(via_tuple(room_code), {:monitor_liveview, pid})
  end

  def handle_track_timeout(room_code) do
    GenServer.call(via_tuple(room_code), :handle_track_timeout)
  end

  # Server callbacks
  @impl true
  def init({room_code, game_mode}) do
    Logger.metadata(room_code: room_code)
    Logger.info("Initializing room", event: :room_init)

    state =
      room_code
      |> RoomState.initialize(game_mode)
      |> PlaybackManager.initialize_playlists()
      |> PlaybackManager.update_track()

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:increment_counter, color}, _from, state) do
    new_state = TeamScoring.increment(state, color)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:decrement_counter, color}, _from, state) do
    new_state = TeamScoring.decrement(state, color)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call(:start_playback, _from, state) do
    new_state = PlaybackManager.start_playback(state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call(:stop_playback, _from, state) do
    new_state = PlaybackManager.stop_playback(state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:update_state, new_state}, _from, _state) do
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:monitor_liveview, pid}, _from, state) do
    Registry.register(Pling.Rooms.ClientRegistry, state.room_code, pid)
    Process.monitor(pid)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    new_state = PlaybackManager.tick(state)
    {:noreply, new_state}
  end

  def handle_info({:monitor_liveview, pid}, state) do
    Registry.register(Pling.Rooms.ClientRegistry, state.room_code, pid)
    Process.monitor(pid)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    Rooms.handle_liveview_down(state.room_code, pid, reason)
    {:noreply, state}
  end

  def via_tuple(room_code) do
    {:via, Registry, {Pling.Rooms.ServerRegistry, room_code}}
  end

  def update_state(room_code, new_state) do
    GenServer.call(via_tuple(room_code), {:update_state, new_state})
  end
end
