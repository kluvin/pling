defmodule Pling.Playlists.Playlist do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:spotify_id, :name, :image_url, :owner, :official]}
  @primary_key {:spotify_id, :string, autogenerate: false}
  schema "playlists" do
    field :name, :string
    field :image_url, :string
    field :owner, :string
    field :official, :boolean, default: false
    has_many :tracks, Pling.Playlists.Track, foreign_key: :playlist_spotify_id

    timestamps()
  end

  def changeset(playlist, attrs) do
    playlist
    |> cast(attrs, [:spotify_id, :name, :official, :image_url, :owner])
    |> validate_required([:spotify_id, :name, :owner])
    |> unique_constraint(:spotify_id, name: :playlists_pkey)
  end
end
