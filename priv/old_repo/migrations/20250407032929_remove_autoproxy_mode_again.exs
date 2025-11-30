defmodule Octocon.Repo.Local.Migrations.RemoveAutoproxyModeAgain do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :autoproxy_mode
    end
  end
end
