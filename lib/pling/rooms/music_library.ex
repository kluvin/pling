defmodule Pling.Rooms.MusicLibrary do
  @moduledoc """
  Manages music playlists and track selection from the database.
  Playlists are organized by decades, with tracks associated to each playlist.
  """
  import Ecto.Query
  alias Pling.Repo
  alias Pling.Rooms.{Playlist, Track}

  @doc """
  Loads all playlists from the database and returns them as a map with decade keys.
  """
  def load_playlists do
    Repo.all(Playlist)
    |> Enum.map(fn playlist -> {playlist.decade, playlist} end)
    |> Enum.into(%{})
  end

  @doc """
  Gets all tracks from all playlists when decade is "mix",
  otherwise gets tracks for the specified decade.
  """
  def get_tracks(_playlists, "mix") do
    Repo.all(Track)
  end

  def get_tracks(_playlists, decade) do
    Playlist
    |> where([p], p.decade == ^decade)
    |> join(:inner, [p], t in assoc(p, :tracks))
    |> select([_p, t], t)
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
  def select_track(playlists, playlist) do
    playlists
    |> get_tracks(playlist)
    |> random_track()
  end
end
