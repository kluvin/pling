defmodule Pling.Rooms.Room.Server do
  use GenServer
  alias Pling.{Rooms.Room.Impl, Presence, Rooms.RoomState}
  require Logger

  def start_link({room_code, _game_mode, _leader_id} = args) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(room_code))
  end

  defp via_tuple(room_code) do
    {:via, Registry, {Pling.Rooms.ServerRegistry, room_code}}
  end

  @impl true
  def init({room_code, game_mode, leader_id}) do
    Logger.metadata(room_code: room_code)
    Logger.info("Initializing room", event: :room_init)
    {:ok, Impl.initialize(room_code, game_mode, leader_id)}
  end

  @impl true
  def handle_cast({:update_score, identifier, amount}, state) do
    new_state = Impl.update_score(state, identifier, amount)

    broadcast(state.room_code, "score_update", %{
      identifier: identifier,
      score: new_state.scores[identifier]
    })

    broadcast(state.room_code, "state_update", %{state: RoomState.for_client(new_state)})
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:process_tick, state) do
    new_state = Impl.process_tick(state)

    if new_state.countdown != state.countdown do
      broadcast(state.room_code, "countdown_update", %{countdown: new_state.countdown})
    end

    if new_state.playing? != state.playing? do
      broadcast(state.room_code, "playback_update", %{playing?: new_state.playing?})
    end

    broadcast(state.room_code, "state_update", %{state: RoomState.for_client(new_state)})
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  @impl true
  def handle_call(:play, _from, state) do
    new_state = Impl.play(state)
    broadcast(state.room_code, "spotify:play", %{playing?: true})
    broadcast(state.room_code, "state_update", %{state: RoomState.for_client(new_state)})
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call(:pause, _from, state) do
    new_state = Impl.pause(state)
    broadcast(state.room_code, "spotify:pause", %{playing?: false})
    broadcast(state.room_code, "ring_bell", %{})
    broadcast(state.room_code, "state_update", %{state: RoomState.for_client(new_state)})
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call(:update_track, _from, state) do
    new_state = Impl.update_track(state)
    broadcast(state.room_code, "spotify:load_track", %{track: new_state.selection.track})
    broadcast(state.room_code, "state_update", %{state: RoomState.for_client(new_state)})
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:set_playlist, playlist}, _from, state) do
    new_state = Impl.set_playlist(state, playlist)
    broadcast(state.room_code, "spotify:load_track", %{track: new_state.selection.track})
    broadcast(state.room_code, "state_update", %{state: RoomState.for_client(new_state)})
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
    new_state = Impl.process_tick(state)
    broadcast(state.room_code, "state_update", %{state: RoomState.for_client(new_state)})
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    Impl.handle_liveview_down(state.room_code, pid, reason)
    {:noreply, state}
  end

  defp broadcast(room_code, event, payload) do
    PlingWeb.Endpoint.broadcast(Presence.topic(room_code), event, payload)
  end
end
