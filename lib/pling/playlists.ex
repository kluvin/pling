defmodule Pling.Playlists do
  @moduledoc """
  The Playlists context.
  Handles CRUD operations for playlists and tracks.
  """

  alias Pling.Repo
  alias Pling.Playlists.{Playlist, Track}

  # Playlist Operations

  @doc """
  Returns the list of playlists.
  """
  def list_playlists do
    Repo.all(Playlist)
  end

  @doc """
  Gets a single playlist by spotify_id.
  Returns nil if the Playlist does not exist.
  """
  def get_playlist(spotify_id) when is_binary(spotify_id) do
    Repo.get(Playlist, spotify_id)
  end

  @doc """
  Gets a single playlist by spotify_id with preloaded tracks.
  Returns nil if the Playlist does not exist.
  """
  def get_playlist_with_tracks(spotify_id) when is_binary(spotify_id) do
    Playlist
    |> Repo.get(spotify_id)
    |> Repo.preload(:tracks)
  end

  @doc """
  Creates a playlist.
  """
  def create_playlist(attrs \\ %{}) do
    %Playlist{}
    |> Playlist.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a playlist.
  """
  def update_playlist(%Playlist{} = playlist, attrs) do
    playlist
    |> Playlist.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a playlist and its associations.
  Returns {:ok, struct} if successful, {:error, reason} otherwise.
  """
  def delete_playlist(%Playlist{} = playlist) do
    Repo.transaction(fn ->
      case Repo.delete(playlist) do
        {:ok, playlist} -> playlist
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking playlist changes.
  """
  def change_playlist(%Playlist{} = playlist, attrs \\ %{}) do
    Playlist.changeset(playlist, attrs)
  end

  @playlist_id_length 22

  @doc """
  Extracts and validates a Spotify playlist ID from either a full Spotify URL or a raw ID.
  Returns nil if the input is invalid.
  """
  def extract_playlist_id("https://open.spotify.com/playlist/" <> potential_id) do
    potential_id = String.slice(potential_id, 0, @playlist_id_length)
    validate_playlist_id(potential_id)
  end

  def extract_playlist_id(potential_id) when is_binary(potential_id) do
    validate_playlist_id(potential_id)
  end

  def extract_playlist_id(_), do: nil

  # IDs are 22 chars
  defp validate_playlist_id(id) do
    if byte_size(id) == @playlist_id_length and id =~ ~r/^[a-zA-Z0-9]{#{@playlist_id_length}}$/ do
      id
    else
      nil
    end
  end

  # Track Operations

  @doc """
  Returns the list of tracks.
  """
  def list_tracks do
    Repo.all(Track)
  end

  @doc """
  Gets a single track by spotify_id.
  Returns nil if the Track does not exist.
  """
  def get_track(spotify_id) when is_binary(spotify_id) do
    Repo.get(Track, spotify_id)
  end

  @doc """
  Gets a single track by spotify_id with preloaded playlists.
  Returns nil if the Track does not exist.
  """
  def get_track_with_playlists(spotify_id) when is_binary(spotify_id) do
    Track
    |> Repo.get(spotify_id)
    |> Repo.preload(:playlists)
  end

  @doc """
  Creates a track.
  """
  def create_track(attrs \\ %{}) do
    %Track{}
    |> Track.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a track.
  """
  def update_track(%Track{} = track, attrs) do
    track
    |> Track.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a track and its associations.
  Returns {:ok, struct} if successful, {:error, reason} otherwise.
  """
  def delete_track(%Track{} = track) do
    Repo.transaction(fn ->
      case Repo.delete(track) do
        {:ok, track} -> track
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking track changes.
  """
  def change_track(%Track{} = track, attrs \\ %{}) do
    Track.changeset(track, attrs)
  end

  # Association Operations

  @doc """
  Adds a track to a playlist.
  """
  def add_track_to_playlist(%Playlist{} = playlist, %Track{} = track) do
    playlist = Repo.preload(playlist, :tracks)
    track = Repo.preload(track, :playlists)

    # Check if association already exists
    if Enum.any?(playlist.tracks, fn t -> t.spotify_id == track.spotify_id end) do
      {:error, :already_exists}
    else
      tracks = [track | playlist.tracks]

      playlist
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:tracks, tracks)
      |> Repo.update()
    end
  end
end
