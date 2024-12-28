defmodule Pling.Rooms.Playlist do
  use Ecto.Schema
  import Ecto.Changeset

  schema "playlists" do
    field :name, :string
    field :decade, :string
    has_many :tracks, Pling.Rooms.Track

    timestamps()
  end

  def changeset(playlist, attrs) do
    playlist
    |> cast(attrs, [:name, :decade])
    |> validate_required([:name, :decade])
    |> unique_constraint(:decade)
  end
end
