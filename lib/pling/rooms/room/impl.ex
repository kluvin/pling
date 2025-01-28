defmodule Pling.Rooms.Room.Impl do
  @moduledoc """
  Handles core business logic for room operations.
  """

  alias Pling.{Rooms.RoomState, Playlists.MusicLibrary}
  require Logger

  def initialize(room_code, game_mode, leader_id, playlist \\ nil) do
    initial_state = RoomState.initialize(room_code, game_mode, leader_id)
    playlists = MusicLibrary.load_playlists()

    state =
      if playlist do
        updated_playlists = Map.put(playlists, playlist.spotify_id, playlist)
        tracks = MusicLibrary.get_tracks(playlist.spotify_id, updated_playlists)
        track = List.first(tracks) || nil

        %{
          initial_state
          | playlists: updated_playlists,
            selection: %{playlist: playlist.spotify_id, track: track}
        }
      else
        initial_state = %{initial_state | playlists: playlists}
        update_track(initial_state)
      end

    update_track(state)
  end

  def play(state) do
    state
    |> Map.put(:timer_ref, cancel_timer(state))
    |> Map.put(:playing?, true)
    |> Map.put(:countdown, 30)
    |> schedule_next_tick()
  end

  def pause(state) do
    state
    |> Map.put(:timer_ref, cancel_timer(state))
    |> Map.put(:countdown, 7)
    |> Map.put(:playing?, false)
    |> schedule_next_tick()
  end

  def update_track(state) do
    current_selection = state.selection

    {new_track, new_queue} =
      case current_selection.queue do
        [next_track | remaining_tracks] ->
          {next_track, remaining_tracks}

        [] ->
          tracks =
            current_selection.playlist
            |> MusicLibrary.get_tracks(state.playlists)
            |> shuffle_tracks()

          {hd(tracks), tl(tracks)}
      end

    %{state | selection: %{
      playlist: current_selection.playlist,
      track: new_track,
      queue: new_queue
    }}
    |> Map.put(:countdown, 30)
  end

  def set_playlist(state, playlist_id) do
    playlists = MusicLibrary.load_playlists()
    playlist = Map.get(playlists, playlist_id)

    tracks =
      playlist_id
      |> MusicLibrary.get_tracks(playlists)
      |> Enum.shuffle()
    {initial_track, initial_queue} =
      {hd(tracks), tl(tracks)}

    state
    |> Map.put(:playlists, playlists)
    |> Map.put(:selection, %{
      playlist: playlist,
      track: initial_track,
      queue: initial_queue
    })
    |> reset_playback()
  end

  def process_tick(state) do
    new_state = tick(state)

    if new_state.countdown && new_state.countdown > 0 do
      schedule_next_tick(new_state)
    else
      %{new_state | timer_ref: nil}
    end
  end

  def update_score(state, identifier, amount) do
    current_score = Map.get(state.scores, identifier, 0)
    put_in(state.scores[identifier], current_score + amount)
  end

  def handle_liveview_down(room_code, _pid, _reason) do
    client_count = count_clients(room_code)

    if client_count <= 1 do
      terminate_room(room_code)
    end

    :ok
  end

  def terminate_room(room_code) do
    case get_room_pid(room_code) do
      {:ok, pid} ->
        GenServer.stop(pid)
        :ok

      :error ->
        :ok
    end
  end

  defp tick(state) do
    case state do
      %{countdown: nil} -> state
      %{countdown: 0} -> handle_timeout(state)
      %{countdown: count} -> update_countdown(state, count - 1)
    end
  end

  defp handle_timeout(state) do
    if state.playing? do
      new_state =
        state
        |> update_track()
        |> Map.put(:countdown, 30)

      schedule_next_tick(new_state)
    else
      %{state | countdown: nil}
    end
  end

  defp update_countdown(state, new_count) do
    %{state | countdown: new_count}
  end

  defp schedule_next_tick(state) do
    timer_ref = Process.send_after(self(), :tick, 1000)
    %{state | timer_ref: timer_ref}
  end

  defp cancel_timer(%{timer_ref: ref}) when is_reference(ref), do: Process.cancel_timer(ref)
  defp cancel_timer(_), do: :ok

  defp reset_playback(state) do
    %{state | playing?: false, countdown: nil, timer_ref: nil}
  end

  defp count_clients(room_code) do
    Registry.lookup(Pling.Rooms.ClientRegistry, room_code)
    |> length()
  end

  defp get_room_pid(room_code) do
    case Registry.lookup(Pling.Rooms.ServerRegistry, room_code) do
      [{pid, _}] -> {:ok, pid}
      [] -> :error
    end
  end

  defp shuffle_tracks(tracks), do: Enum.shuffle(tracks)
end
