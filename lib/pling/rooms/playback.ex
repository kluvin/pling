defmodule Pling.Rooms.Playback do
  @moduledoc """
  Manages playback state for rooms.
  """
  alias Pling.Rooms.{Room, PlaybackManager}
  require Logger

  def start_playback(room_code) do
    Logger.info("Starting playback", room_code: room_code)

    with state <- Room.Impl.get_state(room_code),
         _ <-
           Logger.info("Current state before start",
             room_code: room_code,
             playing?: state.playing?
           ),
         new_state <- PlaybackManager.start_playback(state) do
      Logger.info("New state after start", room_code: room_code, playing?: new_state.playing?)
      Room.Impl.update_state(room_code, new_state)
      {:ok, new_state}
    end
  end

  def stop_playback(room_code) do
    Logger.info("Stopping playback", room_code: room_code)

    with state <- Room.Impl.get_state(room_code),
         _ <-
           Logger.info("Current state before stop",
             room_code: room_code,
             playing?: state.playing?
           ),
         new_state <- PlaybackManager.stop_playback(state) do
      Logger.info("New state after stop", room_code: room_code, playing?: new_state.playing?)
      Room.Impl.update_state(room_code, new_state)
      {:ok, new_state}
    end
  end

  def process_tick(room_code) do
    with state <- Room.Impl.get_state(room_code),
         _ <-
           Logger.debug("Processing tick",
             room_code: room_code,
             playing?: state.playing?,
             countdown: state.countdown
           ),
         new_state <- PlaybackManager.tick(state) do
      Room.Impl.update_state(room_code, new_state)
      {:ok, new_state}
    end
  end

  def process_track_timeout(room_code) do
    Logger.info("Processing track timeout", room_code: room_code)

    with state <- Room.Impl.get_state(room_code),
         _ <-
           Logger.info("Current state before timeout",
             room_code: room_code,
             playing?: state.playing?
           ),
         new_state <- PlaybackManager.handle_track_timeout(state) do
      Logger.info("New state after timeout", room_code: room_code, playing?: new_state.playing?)
      Room.Impl.update_state(room_code, new_state)
    end
  end

  def set_playlist(room_code, playlist) do
    Logger.info("Setting playlist", room_code: room_code, playlist: playlist)

    with state <- Room.Impl.get_state(room_code),
         new_state <- PlaybackManager.change_playlist(state, playlist) do
      Room.Impl.update_state(room_code, new_state)
    end
  end

  def next_track(room_code) do
    Logger.info("Loading next track", room_code: room_code)

    with state <- Room.Impl.get_state(room_code),
         new_state <- PlaybackManager.update_track(state) do
      Room.Impl.update_state(room_code, new_state)
    end
  end
end
