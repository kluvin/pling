defmodule Pling.PlingServer do
  use GenServer
  require Logger
  alias Pling.Services.{PlaylistService, CounterService}

  # State constants
  @initial_state %{
    red_count: 0,
    blue_count: 0,
    is_playing: false,
    countdown: nil,
    timer_threshold: 3,
    spotify_timeout: 30,
    selection: %{playlist: "90s", track: nil},
    playlists: nil,
    room_code: nil
  }

  # Client API
  def start_link(room_code) do
    initial_state = Map.put(@initial_state, :room_code, room_code)
    GenServer.start_link(__MODULE__, initial_state, name: via_tuple(room_code))
  end

  def get_state(room_code) do
    GenServer.call(via_tuple(room_code), :get_state)
  end

  def update_state(room_code, new_state) do
    GenServer.cast(via_tuple(room_code), {:update_state, for_presence(new_state)})
  end

  def reset_state(room_code) do
    GenServer.cast(via_tuple(room_code), :reset_state)
  end

  def increment_counter(room_code, color) do
    GenServer.call(via_tuple(room_code), {:increment_counter, color})
  end

  def decrement_counter(room_code, color) do
    GenServer.call(via_tuple(room_code), {:decrement_counter, color})
  end

  def start_timer(room_code) do
    GenServer.call(via_tuple(room_code), :start_timer)
  end

  def stop_timer(room_code) do
    GenServer.call(via_tuple(room_code), :stop_timer)
  end

  def tick(room_code) do
    GenServer.call(via_tuple(room_code), :tick)
  end

  def set_playlist(room_code, playlist) do
    GenServer.call(via_tuple(room_code), {:set_playlist, playlist})
  end

  def start_playback(room_code) do
    GenServer.call(via_tuple(room_code), :start_playback)
  end

  def stop_playback(room_code) do
    GenServer.call(via_tuple(room_code), :stop_playback)
  end

  def next_track(room_code) do
    GenServer.call(via_tuple(room_code), :next_track)
  end

  def start_ticking(room_code) do
    GenServer.cast(via_tuple(room_code), :start_ticking)
  end

  def stop_ticking(room_code) do
    GenServer.cast(via_tuple(room_code), :stop_ticking)
  end

  # Server Callbacks
  @impl true
  def init(state) do
    playlists = PlaylistService.load_playlists()

    # Set default playlist if none exists
    playlist = state.selection.playlist || "90s"

    new_state =
      state
      |> Map.put(:playlists, playlists)
      |> PlaylistService.update_track(playlist)

    {:ok, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast(:reset_state, _state) do
    {:noreply, @initial_state}
  end

  @impl true
  def handle_cast({:update_state, new_state}, _state) do
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:increment_counter, color}, _from, state) do
    new_state = CounterService.increment(state, color)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:decrement_counter, color}, _from, state) do
    new_state = CounterService.decrement(state, color)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call(:start_timer, _from, state) do
    new_state = %{state | is_playing: true, countdown: state.spotify_timeout}
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call(:stop_timer, _from, state) do
    new_state = %{state | is_playing: false, countdown: nil}
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call(:tick, _from, %{countdown: nil} = state), do: {:reply, state, state}

  @impl true
  def handle_call(:tick, _from, %{countdown: 0} = state) do
    new_state =
      state
      |> PlaylistService.update_track()
      |> Map.put(:countdown, state.spotify_timeout)
      |> Map.put(:is_playing, true)

    {:reply, {:timeout, new_state}, new_state}
  end

  @impl true
  def handle_call(:tick, _from, %{countdown: countdown} = state) do
    new_state = %{state | countdown: countdown - 1}
    broadcast_state_update(state, new_state)
    Process.send_after(self(), :tick, 1000)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:set_playlist, playlist}, _from, state) do
    new_state = PlaylistService.set_playlist(state, playlist)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call(:start_playback, _from, state) do
    new_state =
      state
      |> PlaylistService.update_track()
      |> Map.merge(%{
        is_playing: true,
        countdown: state.spotify_timeout
      })

    # Start the timer immediately
    Process.send_after(self(), :tick, 1000)

    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call(:stop_playback, _from, state) do
    new_state = %{state | is_playing: false, countdown: nil}
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call(:next_track, _from, state) do
    new_state = PlaylistService.update_track(state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_info(:tick, %{is_playing: false} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:tick, %{countdown: nil} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:tick, %{countdown: 0} = state) do
    new_state =
      state
      |> PlaylistService.update_track()
      |> Map.put(:countdown, state.spotify_timeout)

    broadcast_state_update(state, new_state)
    Process.send_after(self(), :tick, 1000)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:tick, %{countdown: countdown} = state) do
    new_state = %{state | countdown: countdown - 1}
    broadcast_state_update(state, new_state)
    Process.send_after(self(), :tick, 1000)
    {:noreply, new_state}
  end

  # Private Functions
  defp via_tuple(room_code) do
    {:via, Registry, {Pling.PlingServerRegistry, room_code}}
  end

  defp broadcast_state_update(old_state, new_state) do
    PlingWeb.Endpoint.broadcast(
      "pling:room:#{new_state.room_code}",
      "state_update",
      %{state: for_presence(new_state)}
    )
  end

  defp for_presence(state) do
    Map.take(state, [
      :red_count,
      :blue_count,
      :is_playing,
      :countdown,
      :selection,
      :timer_threshold,
      :spotify_timeout,
      :room_code
    ])
    |> Map.update!(:selection, &Map.take(&1, [:track, :playlist]))
  end
end
