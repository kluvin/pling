defmodule Pling.Repo.Migrations.SpotifyUsePlaylistFetcherStructure do
  use Ecto.Migration

  def change do
    drop table(:tracks)
    drop table(:playlists)

    create table(:playlists, primary_key: false) do
      add :spotify_id, :string, primary_key: true
      add :name, :string, null: false
      add :official, :boolean, default: false, null: false
      add :image_url, :string
      add :owner, :string, null: false

      timestamps()
    end

    create table(:tracks, primary_key: false) do
      add :spotify_id, :string, primary_key: true
      add :title, :string, null: false
      add :artists, {:array, :string}, null: false
      add :uri, :string, null: false
      add :popularity, :integer
      add :album, :string

      add :playlist_spotify_id, references(:playlists, column: :spotify_id, type: :string),
        null: false

      timestamps()
    end

    create index(:tracks, [:playlist_spotify_id])
  end
end
