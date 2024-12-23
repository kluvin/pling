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

  def update_state(room_code, new_state),
    do: GenServer.cast(via_tuple(room_code), {:update_state, for_presence(new_state)})

  def reset_state(room_code),
    do: GenServer.call(via_tuple(room_code), :reset_state)

  def increment_counter(room_code, color),
    do: GenServer.call(via_tuple(room_code), {:increment_counter, color})

  def decrement_counter(room_code, color),
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

  # Server Callbacks
  @impl true
  def init(state) do
    playlists = PlaylistService.load_playlists()

    new_state =
      state
      |> Map.put(:playlists, playlists)
      |> PlaylistService.update_track(state.selection.playlist)

    {:ok, new_state}
  end

  @impl true
  def handle_cast({:update_state, new_state}, _state) do
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:set_playlist, playlist}, _from, state) do
    new_state = PlaylistService.set_playlist(state, playlist)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:reset_state, _from, _state) do
    new_state = @initial_state
    broadcast(nil, new_state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:increment_counter, color}, _from, state) do
    new_state =
      state
      |> CounterService.increment(color)
      |> maybe_start_new_track()

    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:decrement_counter, color}, _from, state) do
    new_state =
      state
      |> CounterService.decrement(color)
      |> maybe_start_new_track()

    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call(:start_playback, _from, state) do
    new_state =
      state
      |> PlaylistService.update_track()
      |> Map.merge(%{
        is_playing: true,
        countdown: state.spotify_track_duration
      })

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
  def handle_call(:start_timer, _from, state) do
    new_state = %{state | is_playing: true, countdown: state.spotify_track_duration}
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call(:stop_timer, _from, state) do
    new_state = %{state | is_playing: false, countdown: nil}
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

  # Private timer helpers
  defp handle_timer_timeout(state) do
    Logger.info("Changed track due to timeout")

    new_state =
      state
      |> PlaylistService.update_track()
      |> Map.put(:countdown, state.spotify_track_duration)
      |> Map.put(:is_playing, true)
      |> tap(&schedule_next_tick/1)

    PlingWeb.Endpoint.broadcast(
      "pling:room:#{new_state.room_code}",
      "spotify_track_and_play",
      %{track: new_state.selection.track}
    )

    PlingWeb.Endpoint.broadcast(
      "pling:room:#{new_state.room_code}",
      "ring_bell",
      %{}
    )

    new_state
  end

  defp update_countdown(state, new_countdown) do
    new_state = %{state | countdown: new_countdown}
    broadcast(state, new_state)
    schedule_next_tick(new_state)
    new_state
  end

  defp schedule_next_tick(state) when state.is_playing == true do
    Process.send_after(self(), :tick, 1000)
    state
  end

  defp schedule_next_tick(state), do: state

  # State transformation helpers
  defp for_presence(state) do
    state
    |> Map.take(Map.keys(@initial_state))
    |> Map.update!(:selection, &Map.take(&1, [:track, :playlist]))
  end

  defp via_tuple(room_code) do
    {:via, Registry, {Pling.PlingServerRegistry, room_code}}
  end

  defp broadcast(_old_state, new_state) do
    PlingWeb.Endpoint.broadcast(
      "pling:room:#{new_state.room_code}",
      "state_update",
      %{state: for_presence(new_state)}
    )
  end

  defp maybe_start_new_track(%{is_playing: false} = state) do
    new_state =
      state
      |> PlaylistService.update_track()
      |> Map.merge(%{
        is_playing: true,
        countdown: state.spotify_track_duration
      })
      |> tap(&schedule_next_tick/1)

    PlingWeb.Endpoint.broadcast(
      "pling:room:#{new_state.room_code}",
      "spotify_track_and_play",
      %{track: new_state.selection.track}
    )

    new_state
  end

  defp maybe_start_new_track(state), do: state
end
