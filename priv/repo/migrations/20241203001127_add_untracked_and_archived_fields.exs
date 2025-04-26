defmodule Octocon.Repo.Local.Migrations.AddUntrackedAndArchivedFields do
  use Ecto.Migration

  def change do
    alter table(:alters) do
      add :untracked, :boolean, default: false
      add :archived, :boolean, default: false
    end
  end
end
