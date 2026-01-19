defmodule Octocon.Repo.Migrations.AddFriendshipsIndex do
  use Ecto.Migration

  def change do
    create_index("global", "friendships", "friend_id")
  end

  def create_index(keyspace, table, field) when is_binary(keyspace) and is_binary(table) and is_binary(field) do
    name = "#{table}_by_#{field}"

    execute """
    CREATE INDEX IF NOT EXISTS #{name} ON #{keyspace}.#{table} (#{field})
    """, "DROP INDEX #{keyspace}.#{name}"
  end
end
