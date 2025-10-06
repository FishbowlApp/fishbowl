defmodule Octocon.Repo.Migrations.Init do
  use Ecto.Migration

  @keyspaces [
    "nam",
    "eur",
    "ocn",
    "eas",
    "sam",
    "sas",
    "gdpr"
  ]

  def change do
    for keyspace <- @keyspaces do
      create_users_table(keyspace)
      create_alters_table(keyspace)

      create_tags_table(keyspace)
      create_alter_tags_table(keyspace)

      create_global_journals_table(keyspace)
      create_global_journal_alters_table(keyspace)
      create_alter_journals_table(keyspace)

      create_polls_table(keyspace)

      create_fronts_tables(keyspace)
      create_fronts_by_alter_view(keyspace)
      create_fronts_by_time_views(keyspace)

      # Execute the commands on the current keyspace before moving on to the next one
      flush()
    end

    create_user_registry_table()
    create_notification_tokens_table()
    create_channel_blacklists_table()
    create_server_settings_table()

    create_friendships_table()
    create_friend_requests_table()

    create_metrics_table()
  end

  ### REGIONAL TABLES ###

  def create_users_table(keyspace) do
    create_udt(keyspace, "discord_server_settings", """
      guild_id text,
      proxying_disabled boolean,
      autoproxy_mode smallint,
      latched_alter int
    """)

    create_udt(keyspace, "discord_settings", """
      system_tag text,
      show_system_tag boolean,

      case_insensitive_proxies boolean,
      show_pronouns boolean,
      ids_as_proxies boolean,
      silent_proxying boolean,
      use_proxy_delay boolean,

      global_autoproxy_mode smallint,
      global_latched_alter int,

      server_settings list<frozen<#{keyspace}.discord_server_settings>>
    """)

    create_udt(keyspace, "field", """
      id uuid,
      name text,
      type smallint,
      locked boolean,
      security_level smallint
    """)

    create_table(keyspace, "users", """
      id text,
      email text,
      discord_id text,
      apple_id text,
      google_id text,
      username text,

      description text,
      avatar_url text,

      lifetime_alter_count int,
      primary_front int,

      last_proxy_id smallint,
      discord_settings frozen<#{keyspace}.discord_settings>,

      fields list<frozen<#{keyspace}.field>>,

      salt text,
      encryption_initialized boolean,
      encryption_key_checksum text,

      inserted_at timestamp,
      updated_at timestamp
    """, "id")

    create_index(keyspace, "users", "discord_id")
    create_index(keyspace, "users", "email")
    create_index(keyspace, "users", "username")
    create_index(keyspace, "users", "apple_id")
    create_index(keyspace, "users", "google_id")
  end

  def create_alters_table(keyspace) do
    create_udt(keyspace, "alter_field", """
      id uuid,
      value text
    """)

    table_name = "alters"
    create_table(keyspace, table_name, """
      id smallint,
      user_id text,
      alias text,

      name text,
      pronouns text,
      description text,

      avatar_url text,
      security_level smallint,
      extra_images list<text>,
      color text,

      discord_proxies list<text>,
      proxy_name text,

      fields list<frozen<#{keyspace}.alter_field>>,

      untracked boolean,
      archived boolean,
      pinned boolean,
      last_fronted timestamp,

      inserted_at timestamp,
      updated_at timestamp
    """, "user_id, id")

    create_raw_index(keyspace, table_name, "alters_by_alias", "(user_id), alias")
  end

  def create_tags_table(keyspace) do
    create_table(keyspace, "tags", """
      id uuid,
      user_id text,
      parent_tag_id uuid,

      name text,
      description text,
      color text,
      security_level smallint,

      inserted_at timestamp,
      updated_at timestamp
    """, "user_id, id")
  end

  def create_alter_tags_table(keyspace) do
    create_table(keyspace, "alter_tags", """
      user_id text,
      alter_id smallint,
      tag_id uuid,

      inserted_at timestamp,
      updated_at timestamp
    """, "user_id, tag_id, alter_id")

    create_raw_index(keyspace, "alter_tags", "alter_tags_by_alter", "(user_id), alter_id")
  end

  def create_polls_table(keyspace) do
    create_table(keyspace, "polls", """
      id uuid,
      user_id text,

      title text,
      description text,
      type smallint,
      data text,

      time_end timestamp,

      inserted_at timestamp,
      updated_at timestamp
    """, "user_id, id")
  end

  def create_global_journals_table(keyspace) do
    create_table(keyspace, "global_journals", """
      id uuid,
      user_id text,

      title text,
      content text,
      color text,

      pinned boolean,
      locked boolean,

      inserted_at timestamp,
      updated_at timestamp
    """, "user_id, id")
  end

  def create_global_journal_alters_table(keyspace) do
    create_table(keyspace, "global_journal_alters", """
      user_id text,
      global_journal_id uuid,
      alter_id smallint
    """, "user_id, global_journal_id")
  end

  def create_alter_journals_table(keyspace) do
    create_table(keyspace, "alter_journals", """
      id uuid,
      user_id text,
      alter_id smallint,

      title text,
      content text,
      color text,

      pinned boolean,
      locked boolean,

      inserted_at timestamp,
      updated_at timestamp
    """, "user_id, id, alter_id")

    create_raw_index(keyspace, "alter_journals", "alter_journals_by_alter", "(user_id), alter_id")
  end

  def create_alter_journals_by_alter_view(keyspace) do
    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS #{keyspace}.alter_journals_by_alter AS
      SELECT * FROM #{keyspace}.alter_journals
      WHERE user_id IS NOT NULL AND alter_id IS NOT NULL AND id IS NOT NULL
      PRIMARY KEY (user_id, alter_id, id)
    """, "DROP MATERIALIZED VIEW IF EXISTS #{keyspace}.alter_journals_by_alter"
  end

  def create_fronts_tables(keyspace) do
    create_table(keyspace, "fronts", """
      id uuid,
      user_id text,
      alter_id smallint,

      comment text,

      time_start timestamp,
      time_end timestamp,

      inserted_at timestamp,
      updated_at timestamp
    """, "user_id, id, time_start")

    create_table(keyspace, "current_fronts", """
      id uuid,
      user_id text,
      alter_id smallint,

      comment text,

      time_start timestamp,

      inserted_at timestamp,
      updated_at timestamp
    """, "user_id, alter_id")
  end

  def create_fronts_by_alter_view(keyspace) do
    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS #{keyspace}.fronts_by_alter AS
      SELECT * FROM #{keyspace}.fronts
      WHERE user_id IS NOT NULL AND alter_id IS NOT NULL AND id IS NOT NULL AND time_start IS NOT NULL
      PRIMARY KEY (user_id, alter_id, id, time_start)
    """, "DROP MATERIALIZED VIEW IF EXISTS #{keyspace}.fronts_by_alter"
  end

  def create_fronts_by_time_views(keyspace) do
    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS #{keyspace}.fronts_by_time AS
      SELECT * FROM #{keyspace}.fronts
      WHERE user_id IS NOT NULL AND time_start IS NOT NULL AND time_end IS NOT NULL AND id IS NOT NULL
      PRIMARY KEY (user_id, time_start, time_end, id)
    """, "DROP MATERIALIZED VIEW IF EXISTS #{keyspace}.fronts_by_time"

    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS #{keyspace}.fronts_by_end_time AS
      SELECT * FROM #{keyspace}.fronts
      WHERE user_id IS NOT NULL AND time_start IS NOT NULL AND time_end IS NOT NULL AND id IS NOT NULL
      PRIMARY KEY (user_id, time_end, time_start, id)
    """, "DROP MATERIALIZED VIEW IF EXISTS #{keyspace}.fronts_by_end_time"
  end

  ### PINNED TABLES ###

  def create_user_registry_table do
    keyspace = "global"
    table_name = "user_registry"

    create_table(keyspace, table_name, """
      user_id text,
      discord_id text,
      email text,
      username text,
      apple_id text,
      google_id text,
      region text,

      inserted_at timestamp,
      updated_at timestamp
    """, "user_id")

    create_index(keyspace, table_name, "discord_id")
    create_index(keyspace, table_name, "email")
    create_index(keyspace, table_name, "username")
    create_index(keyspace, table_name, "apple_id")
    create_index(keyspace, table_name, "google_id")
  end

  def create_notification_tokens_table do
    keyspace = "global"
    table = "notification_tokens"

    create_table(keyspace, table, """
      user_id text,
      push_token text,

      inserted_at timestamp,
      updated_at timestamp
    """, "user_id, push_token")

    create_index(keyspace, "notification_tokens", "push_token")
  end

  def create_friendships_table do
    keyspace = "global"

    create_table(keyspace, "friendships", """
      user_id text,
      friend_id text,
      level smallint,
      since timestamp,

      inserted_at timestamp,
      updated_at timestamp
    """, "user_id, friend_id")
  end

  def create_friend_requests_table do
    keyspace = "global"
    table = "friend_requests"

    create_table(keyspace, table, """
      from_id text,
      to_id text,
      date_sent timestamp,

      inserted_at timestamp,
      updated_at timestamp
    """, "from_id, to_id")

    create_index(keyspace, table, "to_id")
  end

  def create_channel_blacklists_table do
    keyspace = "nam"
    table = "channel_blacklists"

    create_table(keyspace, table, """
      channel_id text,
      guild_id text,

      inserted_at timestamp,
      updated_at timestamp
    """, "channel_id")

    create_index(keyspace, table, "guild_id")
  end

  def create_server_settings_table do
    create_udt("nam", "server_settings_data", """
      log_channel text,
      force_system_tags boolean,

      proxy_disabled_users list<text>
    """)

    keyspace = "nam"
    table = "server_settings"

    create_table(keyspace, table, """
      guild_id text,
      data frozen<#{keyspace}.server_settings_data>,

      inserted_at timestamp,
      updated_at timestamp
    """, "guild_id")
  end

  def create_metrics_table do
    keyspace = "nam_nt"

    create_table(keyspace, "metrics_counts", """
      key text,
      value counter
    """, "key")
  end

  ### UTILS ###

  def create_udt(keyspace, name, fields) when is_binary(keyspace) and is_binary(name) and is_binary(fields) do
    execute """
    CREATE TYPE IF NOT EXISTS #{keyspace}.#{name} (
      #{fields}
    )
    """, "DROP TYPE IF EXISTS #{keyspace}.#{name}"
  end

  def create_table(keyspace, table, fields, primary_key) when is_binary(keyspace) and is_binary(table) do
    execute """
    CREATE TABLE IF NOT EXISTS #{keyspace}.#{table} (
      #{fields},

      PRIMARY KEY (#{primary_key})
    )
    """, "DROP TABLE IF EXISTS #{keyspace}.#{table}"
  end

  def create_raw_index(keyspace, table, name, on) when is_binary(keyspace) and is_binary(table) and is_binary(name) and is_binary(on) do
    execute """
    CREATE INDEX IF NOT EXISTS #{name} ON #{keyspace}.#{table} (#{on})
    """, "DROP INDEX #{keyspace}.#{name}"
  end

  def create_index(keyspace, table, field) when is_binary(keyspace) and is_binary(table) and is_binary(field) do
    name = "#{table}_by_#{field}"

    execute """
    CREATE INDEX IF NOT EXISTS #{name} ON #{keyspace}.#{table} (#{field})
    """, "DROP INDEX #{keyspace}.#{name}"
  end
end
