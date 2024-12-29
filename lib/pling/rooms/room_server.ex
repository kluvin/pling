defmodule Pling.Rooms.RoomServer do
  use GenServer
  alias Pling.Rooms.{RoomState, PlaybackManager, TeamScoring, FreeForAll}
  alias Pling.Rooms
  require Logger

  # Client API
  def start_link({room_code, game_mode, leader_id}) do
    GenServer.start_link(__MODULE__, {room_code, game_mode, leader_id},
      name: via_tuple(room_code)
    )
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

  def monitor_liveview(room_code, pid) do
    GenServer.call(via_tuple(room_code), {:monitor_liveview, pid})
  end

  def handle_track_timeout(room_code) do
    GenServer.call(via_tuple(room_code), :handle_track_timeout)
  end

  def increment_player_score(room_code, user_id, amount \\ 1) do
    GenServer.call(via_tuple(room_code), {:increment_player_score, user_id, amount})
  end

  def decrement_player_score(room_code, user_id, amount \\ 1) do
    GenServer.call(via_tuple(room_code), {:decrement_player_score, user_id, amount})
  end

  def add_recent_pling(room_code, user_id) do
    GenServer.call(via_tuple(room_code), {:add_recent_pling, user_id})
  end

  def clear_recent_plings(room_code) do
    GenServer.call(via_tuple(room_code), :clear_recent_plings)
  end

  def update_state(room_code, new_state) do
    GenServer.call(via_tuple(room_code), {:update_state, new_state})
  end

  # Server callbacks
  @impl true
  def init({room_code, game_mode, leader_id}) do
    Logger.metadata(room_code: room_code)
    Logger.info("Initializing room", event: :room_init)

    state =
      room_code
      |> RoomState.initialize(game_mode, leader_id)
      |> PlaybackManager.initialize_playlists()
      |> PlaybackManager.update_track()

    {:ok, state}
  end

  # Group all handle_call functions together
  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:increment_counter, color}, _from, state) do
    new_state = TeamScoring.increment(state, color)
    {:reply, new_state, new_state}
  end

  def handle_call({:decrement_counter, color}, _from, state) do
    new_state = TeamScoring.decrement(state, color)
    {:reply, new_state, new_state}
  end

  def handle_call(:start_playback, _from, state) do
    new_state = PlaybackManager.start_playback(state)
    broadcast_state_update(new_state.room_code, new_state)
    {:reply, new_state, new_state}
  end

  def handle_call(:stop_playback, _from, state) do
    new_state = PlaybackManager.stop_playback(state)
    broadcast_state_update(new_state.room_code, new_state)
    {:reply, new_state, new_state}
  end

  def handle_call({:update_state, new_state}, _from, _state) do
    broadcast_state_update(new_state.room_code, new_state)
    {:reply, new_state, new_state}
  end

  def handle_call({:monitor_liveview, pid}, _from, state) do
    Registry.register(Pling.Rooms.ClientRegistry, state.room_code, pid)
    Process.monitor(pid)
    {:reply, :ok, state}
  end

  def handle_call({:increment_player_score, user_id, amount}, _from, state) do
    new_state = FreeForAll.increment_score(state, user_id, amount)
    broadcast_state_update(state.room_code, new_state)
    {:reply, new_state, new_state}
  end

  def handle_call({:decrement_player_score, user_id, amount}, _from, state) do
    new_state = FreeForAll.decrement_score(state, user_id, amount)
    broadcast_state_update(state.room_code, new_state)
    {:reply, new_state, new_state}
  end

  def handle_call({:add_recent_pling, user_id}, _from, state) do
    new_state = FreeForAll.add_pling(state, user_id)
    broadcast_state_update(state.room_code, new_state)
    {:reply, new_state, new_state}
  end

  def handle_call(:clear_recent_plings, _from, state) do
    new_state = FreeForAll.clear_plings(state)
    broadcast_state_update(state.room_code, new_state)
    {:reply, new_state, new_state}
  end

  # Handle info callbacks
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

  # Private functions
  defp via_tuple(room_code) do
    {:via, Registry, {Pling.Rooms.ServerRegistry, room_code}}
  end

  defp broadcast_state_update(room_code, state) do
    Logger.info("Broadcasting state update",
      scores: inspect(state.player_scores),
      room_code: room_code
    )

    Phoenix.PubSub.broadcast(
      Pling.PubSub,
      "room:#{room_code}",
      %{event: "state_update", payload: %{state: RoomState.for_client(state)}}
    )
  end
end
