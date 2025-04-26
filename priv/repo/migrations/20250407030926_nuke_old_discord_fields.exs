defmodule Octocon.Repo.Local.Migrations.NukeOldDiscordFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :system_tag
      remove :show_system_tag
      remove :case_insensitive_proxying
      remove :show_proxy_pronouns
      remove :ids_as_proxies
      remove :latched_alter
      remove :autoproxy_mode
      remove :last_proxy_id
    end
  end
end
