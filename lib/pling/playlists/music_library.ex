defmodule Pling.Playlists.MusicLibrary do
  @moduledoc """
  Manages music playlists and track selection from the database.
  Playlists are organized by decades, with tracks associated to each playlist.
  """
  import Ecto.Query
  require Logger
  alias Pling.Repo
  alias Pling.Playlists.{Playlist, Track}

  @notification_key :first_track_notified

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
    Playlist
    |> where([p], p.spotify_id == ^playlist_id)
    |> preload(:tracks)
    |> Repo.one()
    |> case do
      nil -> []
      playlist -> playlist.tracks
    end
  end

  @doc """
  Selects a random track from the given list of tracks.
  """
  def random_track([]), do: nil
  def random_track(tracks), do: Enum.random(tracks)

  @doc """
  Selects a random track from the specified playlist.
  If no playlist is specified or if playlists map is empty, uses the default playlist.
  """
  def select_track(playlists, playlist_id) when is_map(playlists) do
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
        notification_agent = Process.spawn(fn -> receive do: (_ -> :ok) end, [])

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
            result =
              Repo.transaction(fn ->
                track_entry = %Track{
                  uri: track["uri"],
                  title: track["name"],
                  artists: Enum.map(track["artists"], & &1["name"]),
                  popularity: track["popularity"],
                  album: track["album"]["name"]
                }

                # First ensure the track exists
                {:ok, saved_track} = Repo.insert(track_entry, on_conflict: :nothing)

                # Then create the association only if track was saved
                if saved_track.uri do
                  {1, _} =
                    Repo.insert_all(
                      "playlist_tracks",
                      [
                        %{
                          track_uri: saved_track.uri,
                          playlist_spotify_id: spotify_id,
                          inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
                          updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
                        }
                      ],
                      on_conflict: :nothing
                    )
                end

                # Notify parent process of first track
                if not Process.get(@notification_key) do
                  Process.put(@notification_key, true)
                  send(parent, {:first_track_saved, ref, spotify_id})
                end

                saved_track
              end)

            # Try to notify of first track - only the first message will be received
            try do
              send(notification_agent, :notified)
              send(parent, {:first_track_saved, ref, spotify_id})
            catch
              # Process already notified
              :error, :badarg -> :ok
            end

            result
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
