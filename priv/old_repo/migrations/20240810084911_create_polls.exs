defmodule Octocon.Repo.Local.Migrations.CreatePolls do
  use Ecto.Migration

  def change do
    create table(:polls, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, type: :string, on_delete: :delete_all), size: 7
      add :title, :text

      add :type, :int2
      add :data, :map
      add :time_end, :utc_datetime

      timestamps()
    end

    create index(:polls, [:user_id])
  end
end
