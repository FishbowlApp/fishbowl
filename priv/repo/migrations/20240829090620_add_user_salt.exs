defmodule Octocon.Repo.Local.Migrations.AddUserSalt do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :salt, :text
    end
  end
end
