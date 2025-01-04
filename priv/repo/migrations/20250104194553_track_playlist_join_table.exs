defmodule Pling.Repo.Migrations.TrackPlaylistJoinTable do
  use Ecto.Migration

  def change do
    # Create playlists table with spotify_id as primary key
    create table(:playlists, primary_key: false) do
      add :spotify_id, :string, primary_key: true, null: false
      add :name, :string, null: false
      add :official, :boolean, default: false, null: false
      add :image_url, :string
      add :owner, :string, null: false

      timestamps()
    end

    create unique_index(:playlists, [:spotify_id])

    # Create tracks table with uri as primary key (full spotify URI format)
    create table(:tracks, primary_key: false) do
      add :uri, :string, primary_key: true, null: false, size: 100
      add :title, :string, null: false
      add :artists, {:array, :string}, null: false
      add :popularity, :integer
      add :album, :string

      timestamps()
    end

    create unique_index(:tracks, [:uri])

    # Create the join table for many-to-many relationship
    create table(:playlist_tracks, primary_key: false) do
      add :playlist_spotify_id,
          references(:playlists, column: :spotify_id, type: :string, on_delete: :delete_all),
          null: false

      add :track_uri,
          references(:tracks, column: :uri, type: :string, on_delete: :delete_all),
          null: false

      timestamps()
    end

    # Add indexes for better query performance
    create index(:playlist_tracks, [:playlist_spotify_id])
    create index(:playlist_tracks, [:track_uri])

    # Ensure no duplicate combinations of playlist and track
    create unique_index(:playlist_tracks, [:playlist_spotify_id, :track_uri],
             name: :playlist_track_unique_assoc
           )
  end
end
