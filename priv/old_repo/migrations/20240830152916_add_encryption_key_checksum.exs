defmodule Octocon.Repo.Local.Migrations.AddEncryptionKeyChecksum do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :encryption_key_checksum, :text
    end
  end
end
