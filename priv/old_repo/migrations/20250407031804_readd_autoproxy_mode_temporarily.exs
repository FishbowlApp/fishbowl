defmodule Octocon.Repo.Local.Migrations.ReaddAutoproxyModeTemporarily do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :autoproxy_mode, :integer
    end
  end
end
