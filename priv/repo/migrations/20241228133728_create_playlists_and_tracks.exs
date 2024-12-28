defmodule Pling.Repo.Migrations.CreatePlaylistsAndTracks do
  use Ecto.Migration

  def change do
    create table(:playlists) do
      add :name, :string, null: false
      add :decade, :string, null: false

      timestamps()
    end

    create table(:tracks) do
      add :title, :string
      add :artist, :string
      add :uri, :string, null: false
      add :playlist_id, references(:playlists, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:tracks, [:playlist_id])
    create unique_index(:playlists, [:decade])
  end
end
