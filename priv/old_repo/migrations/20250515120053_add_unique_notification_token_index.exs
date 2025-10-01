defmodule Octocon.Repo.Local.Migrations.AddUniqueNotificationTokenIndex do
  use Ecto.Migration

  def change do
    create unique_index(:notification_tokens, [:token])
  end
end
