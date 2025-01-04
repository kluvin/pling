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
        # Merge the custom playlist with existing playlists
        updated_playlists = Map.put(playlists, playlist.spotify_id, playlist)

        %{
          initial_state
          | playlists: updated_playlists,
            selection: %{playlist: playlist.spotify_id, track: nil}
        }
      else
        if Enum.empty?(playlists) do
          Logger.warning("No playlists found in database, room may not function correctly")

          %{
            initial_state
            | playlists: %{
                "6ZSeHvrhmEH4erjxudpULB" => %{
                  spotify_id: "6ZSeHvrhmEH4erjxudpULB",
                  name: "Default Playlist"
                }
              }
          }
        else
          %{initial_state | playlists: playlists}
        end
      end

    update_track(state)
  end

  def play(state) do
    state
    |> Map.put(:playing?, true)
    |> Map.put(:countdown, state.spotify_track_duration)
    |> schedule_next_tick()
  end

  def pause(state) do
    state
    |> Map.put(:timer_ref, cancel_timer(state))
    |> reset_playback()
  end

  def update_track(state) do
    case select_track(state) do
      nil -> state
      track -> %{state | selection: %{playlist: state.selection.playlist, track: track}}
    end
  end

  defp select_track(%{playlists: nil}), do: nil

  defp select_track(%{selection: %{playlist: nil}, playlists: playlists})
       when not is_nil(playlists) do
    MusicLibrary.select_track(playlists, nil)
  end

  defp select_track(%{selection: %{playlist: playlist_id}, playlists: playlists})
       when not is_nil(playlists) do
    MusicLibrary.select_track(playlists, playlist_id)
  end

  def set_playlist(state, playlist_id) do
    state
    |> Map.put(:selection, %{playlist: playlist_id, track: nil})
    |> update_track()
    |> reset_playback()
  end

  def process_tick(state) do
    new_state = tick(state)

    if new_state.playing? do
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
      %{playing?: false} -> state
      %{countdown: nil} -> state
      %{countdown: 0} -> handle_timeout(state)
      %{countdown: count} -> update_countdown(state, count - 1)
    end
  end

  defp handle_timeout(state) do
    new_state =
      state
      |> update_track()
      |> Map.put(:countdown, state.spotify_track_duration)
      |> Map.put(:playing?, false)

    new_state
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
end
