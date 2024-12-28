defmodule Pling.Rooms.PlaybackManager do
  @moduledoc """
  Manages room playback state, track transitions, and timing.
  """

  alias Pling.Rooms.{MusicLibrary, Broadcaster}
  require Logger

  def initialize_playlists(state) do
    Map.put(state, :playlists, MusicLibrary.load_playlists())
  end

  def update_track(state) do
    track = MusicLibrary.select_track(state.playlists, state.selection.playlist)
    Logger.info("Loading new track: #{inspect(track)} for room: #{state.room_code}")

    new_state = %{state | selection: %{playlist: state.selection.playlist, track: track}}
    Broadcaster.broadcast_track_load(state.room_code, track)
    new_state
  end

  def change_playlist(state, playlist) do
    Logger.info("Changing playlist to: #{playlist} for room: #{state.room_code}")
    state
    |> Map.put(:selection, %{playlist: playlist, track: nil})
    |> update_track()
    |> reset_playback()
  end

  def start_playback(state) do
    Logger.info("Starting playback for room: #{state.room_code}")
    new_state = %{state |
      playing?: true,
      countdown: state.spotify_track_duration
    }
    Broadcaster.broadcast_toggle_play(state.room_code)
    schedule_next_tick(new_state)
  end

  def stop_playback(state) do
    Logger.info("Stopping playback for room: #{state.room_code}")
    cancel_timer(state)
    Broadcaster.broadcast_bell(state.room_code)
    Broadcaster.broadcast_toggle_play(state.room_code)
    reset_playback(state)
  end

  def tick(state) do
    case state do
      %{playing?: false} -> state
      %{countdown: nil} -> state
      %{countdown: 0} -> handle_timeout(state)
      %{countdown: count} -> update_countdown(state, count - 1)
    end
  end

  def handle_track_timeout(state) do
    new_state =
      state
      |> update_track()
      |> Map.put(:countdown, state.spotify_track_duration)
      |> Map.put(:playing?, false)

    Broadcaster.broadcast_bell(state.room_code)
    new_state
  end

  defp handle_timeout(state) do
    Logger.info("Track timeout for room: #{state.room_code}")
    new_state =
      state
      |> update_track()
      |> Map.put(:countdown, state.spotify_track_duration)
      |> Map.put(:playing?, false)

    Broadcaster.broadcast_bell(state.room_code)
    new_state
  end

  defp update_countdown(state, new_count) do
    new_state = %{state | countdown: new_count}
    schedule_next_tick(new_state)
    new_state
  end

  defp schedule_next_tick(%{playing?: true} = state) do
    timer_ref = Process.send_after(self(), :tick, 1000)
    %{state | timer_ref: timer_ref}
  end
  defp schedule_next_tick(state), do: state

  defp cancel_timer(%{timer_ref: ref}) when is_reference(ref), do: Process.cancel_timer(ref)
  defp cancel_timer(_), do: :ok

  defp reset_playback(state) do
    %{state |
      playing?: false,
      countdown: nil,
      timer_ref: nil
    }
  end
end
