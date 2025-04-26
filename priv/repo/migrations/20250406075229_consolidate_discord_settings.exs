defmodule Octocon.Repo.Local.Migrations.ConsolidateDiscordSettings do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :discord_settings, :map, default: %{}
    end
  end
end
