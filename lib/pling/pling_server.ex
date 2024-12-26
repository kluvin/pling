defmodule Pling.PlingServer do
  use GenServer
  require Logger
  alias Pling.Services.{PlaylistService, CounterService}

  # Module attributes for organization
  @initial_state %{
    red_count: 0,
    blue_count: 0,
    is_playing: false,
    countdown: nil,
    timer_ref: nil,
    timer_threshold: 10,
    spotify_track_duration: 30,
    selection: %{playlist: "90s", track: nil},
    playlists: nil,
    room_code: nil
  }

  # Client API
  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(room_code) do
    initial_state = Map.put(@initial_state, :room_code, room_code)
    GenServer.start_link(__MODULE__, initial_state, name: via_tuple(room_code))
  end

  def get_state(room_code) do
    GenServer.call(via_tuple(room_code), :get_state)
  end

  def reset_state(room_code),
    do: GenServer.call(via_tuple(room_code), :reset_state)

  def counter(:increment, room_code, color),
    do: GenServer.call(via_tuple(room_code), {:increment_counter, color})

  def counter(:decrement, room_code, color),
    do: GenServer.call(via_tuple(room_code), {:decrement_counter, color})

  # Timer-specific API
  def start_timer(room_code), do: GenServer.call(via_tuple(room_code), :start_timer)
  def stop_timer(room_code), do: GenServer.call(via_tuple(room_code), :stop_timer)
  def tick(room_code), do: GenServer.call(via_tuple(room_code), :tick)

  # Playback-specific API
  def start_playback(room_code), do: GenServer.call(via_tuple(room_code), :start_playback)
  def stop_playback(room_code), do: GenServer.call(via_tuple(room_code), :stop_playback)
  def next_track(room_code), do: GenServer.call(via_tuple(room_code), :next_track)

  def set_playlist(room_code, playlist),
    do: GenServer.call(via_tuple(room_code), {:set_playlist, playlist})

  # ------------------------------------------------------------------
  # Server Callbacks
  # ------------------------------------------------------------------

  @impl true
  def init(state) do
    playlists = PlaylistService.load_playlists()

    new_state =
      state
      |> Map.put(:playlists, playlists)
      |> PlaylistService.update_track()

    {:ok, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:reset_state, _from, _old_state) do
    new_state = @initial_state
    broadcast(nil, new_state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:increment_counter, color}, _from, state) do
    new_state =
      state
      |> CounterService.increment(color)
      |> load_new_track()

    broadcast(state, new_state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:decrement_counter, color}, _from, state) do
    new_state =
      state
      |> CounterService.decrement(color)
      |> load_new_track()

    broadcast(state, new_state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call(:start_playback, _from, state) do
    new_state = PlaylistService.start_playback(state)
    # Optionally schedule a tick
    Process.send_after(self(), :tick, 1000)
    broadcast(state, new_state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call(:stop_playback, _from, state) do
    new_state = PlaylistService.stop_playback(state)
    # Also ring the bell
    PlingWeb.Endpoint.broadcast(
      "pling:room:#{new_state.room_code}",
      "ring_bell",
      %{}
    )

    broadcast(state, new_state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call(:next_track, _from, state) do
    new_state = PlaylistService.update_track(state)
    broadcast(state, new_state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:set_playlist, playlist}, _from, state) do
    new_state = PlaylistService.set_playlist(state, playlist)
    broadcast(state, new_state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call(:start_timer, _from, state) do
    new_state = %{state | is_playing: true, countdown: state.spotify_track_duration}
    broadcast(state, new_state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call(:stop_timer, _from, state) do
    new_state = %{state | is_playing: false, countdown: nil}
    broadcast(state, new_state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call(:tick, _from, %{countdown: nil} = state), do: {:reply, state, state}

  def handle_call(:tick, _from, %{countdown: 0} = state) do
    new_state = handle_timer_timeout(state)
    {:reply, {:timeout, new_state}, new_state}
  end

  def handle_call(:tick, _from, %{countdown: countdown} = state) do
    new_state = update_countdown(state, countdown - 1)
    {:reply, new_state, new_state}
  end

  # ------------------------------------------------------------------
  # Asynchronous Messages
  # ------------------------------------------------------------------
  @impl true
  def handle_info(:tick, %{is_playing: false} = state), do: {:noreply, state}
  def handle_info(:tick, %{countdown: nil} = state), do: {:noreply, state}

  def handle_info(:tick, %{countdown: 0} = state) do
    new_state = handle_timer_timeout(state)
    {:noreply, new_state}
  end

  def handle_info(:tick, %{countdown: countdown} = state) do
    new_state = update_countdown(state, countdown - 1)
    {:noreply, new_state}
  end

  # Monitor LiveView process
  @impl true
  def handle_info({:monitor_liveview, pid}, state) do
    # Register client in the Registry instead of state
    Registry.register(Pling.ClientRegistry, state.room_code, pid)
    # Still monitor for cleanup
    Process.monitor(pid)

    client_count = count_clients(state.room_code)

    Logger.info("LiveView connected",
      event: :liveview_monitor,
      pid: inspect(pid),
      connection_count: client_count
    )

    {:noreply, state}
  end

  # Handle LiveView process termination
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    client_count = count_clients(state.room_code)

    Logger.info("LiveView disconnected",
      event: :liveview_down,
      pid: inspect(pid),
      reason: reason,
      # One is about to be removed
      connection_count: client_count - 1
    )

    # Count includes the process that's terminating
    if client_count <= 1 do
      Logger.info("No more connections, terminating", event: :server_terminate)
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  # ------------------------------------------------------------------
  # Private Helpers
  # ------------------------------------------------------------------

  defp handle_timer_timeout(state) do
    Logger.info("Changed track due to timeout")

    new_state =
      state
      |> PlaylistService.update_track()
      |> Map.put(:countdown, state.spotify_track_duration)
      |> Map.put(:is_playing, false)

    PlingWeb.Endpoint.broadcast(
      "pling:room:#{new_state.room_code}",
      "ring_bell",
      %{}
    )

    broadcast(state, new_state)
    new_state
  end

  defp update_countdown(state, new_countdown) do
    new_state = %{state | countdown: new_countdown}
    schedule_next_tick(new_state)
    broadcast(state, new_state)
    new_state
  end

  defp schedule_next_tick(state) when state.is_playing == true do
    timer_ref = Process.send_after(self(), :tick, 1000)
    %{state | timer_ref: timer_ref}
  end

  defp schedule_next_tick(state), do: state

  defp load_new_track(%{is_playing: false} = state) do
    new_state = PlaylistService.update_track(state)

    PlingWeb.Endpoint.broadcast(
      "pling:room:#{new_state.room_code}",
      "spotify:load_track",
      %{track: new_state.selection.track}
    )

    broadcast(state, new_state)
    new_state
  end

  defp load_new_track(state), do: state

  # Called whenever we have a new state to share with LiveView
  defp broadcast(_old_state, new_state) do
    PlingWeb.Endpoint.broadcast(
      "pling:room:#{new_state.room_code}",
      "state_update",
      %{state: for_client(new_state)}
    )
  end

  defp for_client(state) do
    %{
      red_count: state.red_count,
      blue_count: state.blue_count,
      is_playing: state.is_playing,
      countdown: state.countdown,
      timer_threshold: state.timer_threshold,
      selection: Map.take(state.selection, [:track, :playlist])
    }
  end

  def via_tuple(room_code) do
    {:via, Registry, {Pling.PlingServerRegistry, room_code}}
  end

  defp count_clients(room_code) do
    room_code
    |> clients()
    |> length()
  end

  defp clients(room_code) do
    Registry.lookup(Pling.ClientRegistry, room_code)
  end
end
