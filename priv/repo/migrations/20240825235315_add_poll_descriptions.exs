defmodule Octocon.Repo.Local.Migrations.AddPollDescriptions do
  use Ecto.Migration

  def change do
    alter table(:polls) do
      add :description, :text
    end
  end
end
