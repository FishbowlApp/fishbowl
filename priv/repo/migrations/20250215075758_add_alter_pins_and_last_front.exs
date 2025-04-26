defmodule Octocon.Repo.Local.Migrations.AddAlterPinsAndLastFront do
  use Ecto.Migration

  def change do
    alter table(:alters) do
      add :pinned, :boolean, default: false
      add :last_fronted, :utc_datetime, default: nil
    end
  end
end
