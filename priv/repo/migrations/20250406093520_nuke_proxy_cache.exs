defmodule Octocon.Repo.Local.Migrations.NukeProxyCache do
  use Ecto.Migration

  def change do
    drop_if_exists table(:proxy_cache_items)
  end
end
