defmodule Octocon.Repo.Local.Migrations.AddAuthIds do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :apple_id, :text, default: nil
      add :google_id, :text, default: nil
    end

    create unique_index(:users, [:apple_id])
    create unique_index(:users, [:google_id])
  end
end
