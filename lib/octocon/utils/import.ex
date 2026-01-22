defmodule Octocon.Utils.Import do
  alias Octocon.Alters.Alter

  def naive_datetime_to_datetime(naive_datetime) do
    {:ok, datetime} =
      Exandra.dumpers(:naive_datetime, nil)
      |> List.first()
      |> then(fn dumper -> dumper.(naive_datetime) end)

    datetime
  end

  def alter_to_insert_query(%Alter{
    user_id: user_id,
    id: id,
    name: name,
    proxy_name: proxy_name,
    discord_proxies: discord_proxies,
    pronouns: pronouns,
    description: description,
    alias: aliaz,
    pinned: pinned,
    archived: archived,
    last_fronted: last_fronted,
    color: color,
    fields: fields,
    inserted_at: inserted_at,
    updated_at: updated_at
  }, region) do
    query = "INSERT INTO #{region}.alters (user_id, id, name, proxy_name, discord_proxies, pronouns, description, alias, pinned, archived, last_fronted, color, fields, inserted_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    values = [
      user_id,
      id,
      name,
      proxy_name,
      discord_proxies,
      pronouns,
      description,
      aliaz,
      pinned,
      archived,
      last_fronted,
      color,
      fields,
      inserted_at,
      updated_at
    ]

    {query, values}
  end
end
