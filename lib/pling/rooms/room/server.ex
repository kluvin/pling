defmodule Pling.Rooms.Room.Server do
  use GenServer
  alias Pling.Rooms.Room.Impl
  require Logger

  def start_link({room_code, _game_mode, _leader_id} = init_args) do
    GenServer.start_link(__MODULE__, init_args, name: Impl.via_tuple(room_code))
  end

  @impl true
  def init({room_code, game_mode, leader_id}) do
    Logger.metadata(room_code: room_code)
    Logger.info("Initializing room", event: :room_init)
    {:ok, Impl.initialize(room_code, game_mode, leader_id)}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:start_playback, _from, state) do
    new_state = Impl.start_playback(state)
    broadcast_state_update(new_state.room_code, new_state)
    {:reply, new_state, new_state}
  end

  def handle_call(:stop_playback, _from, state) do
    new_state = Impl.stop_playback(state)
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

  # Handle info callbacks
  @impl true
  def handle_info(:tick, state) do
    new_state = Impl.handle_tick(state)
    {:noreply, new_state}
  end

  def handle_info({:monitor_liveview, pid}, state) do
    Registry.register(Pling.Rooms.ClientRegistry, state.room_code, pid)
    Process.monitor(pid)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    Impl.handle_liveview_down(state.room_code, pid, reason)
    {:noreply, state}
  end

  defp broadcast_state_update(room_code, state) do
    Logger.info("Broadcasting state update",
      scores: inspect(state.scores),
      room_code: room_code
    )

    Phoenix.PubSub.broadcast(
      Pling.PubSub,
      "room:#{room_code}",
      %{event: "state_update", payload: %{state: Impl.for_client(state)}}
    )
  end
end
