defmodule Pling.Playlists.MusicLibrary do
  @moduledoc """
  Manages music playlists and track selection from the database.
  Playlists are organized by decades, with tracks associated to each playlist.
  """
  import Ecto.Query
  require Logger
  alias Pling.Repo
  alias Pling.Playlists.{Playlist, Track}

  @doc """
  Loads all playlists from the database and returns them as a map with spotify_id keys.
  """
  def load_playlists do
    Playlist
    |> preload(:tracks)
    |> Repo.all()
    |> Enum.map(fn playlist -> {playlist.spotify_id, playlist} end)
    |> Enum.into(%{})
  end

  @doc """
  Gets all tracks from all playlists when playlist is "mix",
  otherwise gets tracks for the specified playlist.
  """
  def get_tracks(playlist_id, _playlists) when playlist_id == "mix" do
    Repo.all(Track)
  end

  def get_tracks(playlist_id, _playlists) when is_binary(playlist_id) do
    Track
    |> where([t], t.playlist_spotify_id == ^playlist_id)
    |> Repo.all()
  end

  @doc """
  Selects a random track from the given list of tracks.
  """
  def random_track([]), do: nil
  def random_track(tracks), do: Enum.random(tracks)

  @doc """
  Selects a random track from the specified playlist.
  Returns nil if no tracks are found.
  """
  def select_track(playlists, nil) when is_map(playlists) and map_size(playlists) > 0 do
    # If no playlist specified, pick a random one
    {playlist_id, _} = Enum.random(playlists)
    select_track(playlists, playlist_id)
  end

  def select_track(_playlists, nil), do: nil

  def select_track(playlists, playlist_id) do
    get_tracks(playlist_id, playlists)
    |> random_track()
  end

  @doc """
  Gets a playlist by Spotify ID, fetching it from Spotify if it doesn't exist locally.
  Returns the playlist as soon as it has basic info and at least one track.
  """
  def get_or_fetch_playlist(spotify_id, timeout \\ 5000) do
    case Repo.get(Playlist, spotify_id) do
      nil ->
        ref = make_ref()
        parent = self()

        callback = fn
          %{"playlist_info" => info} ->
            playlist = %Playlist{
              spotify_id: spotify_id,
              name: info["name"],
              owner: info["owner"],
              image_url: get_first_image_url(info["images"]),
              official: false
            }

            {:ok, saved_playlist} = Repo.insert(playlist)
            saved_playlist

          %{"track" => track} ->
            track_entry = %Track{
              spotify_id: track["id"],
              title: track["name"],
              artists: Enum.map(track["artists"], & &1["name"]),
              uri: track["uri"],
              popularity: track["popularity"],
              album: track["album"]["name"],
              playlist_spotify_id: spotify_id
            }

            {:ok, saved_track} = Repo.insert(track_entry, on_conflict: :nothing)

            # Notify parent process of first track
            if not Process.get({:notified_first_track, ref}) do
              Process.put({:notified_first_track, ref}, true)
              send(parent, {:first_track_saved, ref, spotify_id})
            end

            saved_track
        end

        Task.start(fn ->
          case Pling.Services.Spotify.stream_playlist(spotify_id, callback) do
            :ok ->
              :ok

            {:error, reason} ->
              Logger.error("Failed to fetch complete playlist: #{inspect(reason)}")
              # Notify parent in case of immediate error
              send(parent, {:playlist_error, ref, reason})
          end
        end)

        receive do
          {:first_track_saved, ^ref, playlist_id} ->
            case Repo.get(Playlist, playlist_id) do
              nil -> {:error, :playlist_fetch_failed}
              playlist -> {:ok, :first_track_saved, playlist}
            end

          {:playlist_error, ^ref, reason} ->
            {:error, reason}
        after
          timeout ->
            case Repo.get(Playlist, spotify_id) do
              nil -> {:error, :playlist_fetch_timeout}
              playlist -> {:ok, :timeout, playlist}
            end
        end

      playlist ->
        {:ok, :exists, playlist}
    end
  end

  @doc """
  Returns a callback that just outputs the streaming data.
  Useful for debugging or monitoring the stream.
  """
  def debug_callback do
    fn
      %{"playlist_info" => info} ->
        IO.puts("Playlist Info:")
        IO.inspect(info, pretty: true)
        :ok

      %{"track" => track} ->
        IO.puts("\nTrack:")
        IO.inspect(track, pretty: true)
        :ok
    end
  end

  defp get_first_image_url([%{"url" => url} | _]), do: url
  defp get_first_image_url(_), do: nil
end
