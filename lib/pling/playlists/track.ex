defmodule Pling.Playlists.Track do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:spotify_id, :title, :artists, :uri, :popularity, :album]}
  @primary_key {:spotify_id, :string, autogenerate: false}
  schema "tracks" do
    field :title, :string
    field :artists, {:array, :string}
    field :uri, :string
    field :popularity, :integer
    field :album, :string

    belongs_to :playlist, Pling.Playlists.Playlist,
      foreign_key: :playlist_spotify_id,
      references: :spotify_id,
      type: :string

    timestamps()
  end

  def changeset(track, attrs) do
    track
    |> cast(attrs, [
      :spotify_id,
      :title,
      :artists,
      :uri,
      :playlist_spotify_id,
      :popularity,
      :album
    ])
    |> validate_required([:spotify_id, :uri, :playlist_spotify_id, :title, :artists])
    |> foreign_key_constraint(:playlist_spotify_id)
  end
end
