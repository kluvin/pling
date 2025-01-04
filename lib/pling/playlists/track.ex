defmodule Pling.Playlists.Track do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:uri, :title, :artists, :popularity, :album]}
  @primary_key {:uri, :string, autogenerate: false}
  @foreign_key_type :string
  schema "tracks" do
    field :title, :string
    field :artists, {:array, :string}
    field :popularity, :integer
    field :album, :string

    many_to_many :playlists, Pling.Playlists.Playlist,
      join_through: "playlist_tracks",
      join_keys: [track_uri: :uri, playlist_spotify_id: :spotify_id]

    timestamps()
  end

  def changeset(track, attrs) do
    track
    |> cast(attrs, [:uri, :title, :artists, :popularity, :album])
    |> validate_required([:uri, :title, :artists])
  end
end
