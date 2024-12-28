defmodule Pling.Rooms.Track do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [:id, :title, :artist, :uri, :playlist_id, :inserted_at, :updated_at]}

  schema "tracks" do
    field :title, :string
    field :artist, :string
    field :uri, :string
    belongs_to :playlist, Pling.Rooms.Playlist

    timestamps()
  end

  def changeset(track, attrs) do
    track
    |> cast(attrs, [:title, :artist, :uri, :playlist_id])
    |> validate_required([:uri, :playlist_id])
    |> foreign_key_constraint(:playlist_id)
  end
end
