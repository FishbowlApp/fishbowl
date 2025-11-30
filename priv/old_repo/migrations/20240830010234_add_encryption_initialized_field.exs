defmodule Octocon.Repo.Local.Migrations.AddEncryptionInitializedField do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :encryption_initialized, :boolean, default: false
    end
  end
end
