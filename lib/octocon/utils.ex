defmodule Octocon.Utils do
  alias ExAws.S3

  def nuke_existing_avatars!(system_id, folder) do
    bucket = Application.fetch_env!(:waffle, :bucket)
    path = "uploads/avatars/#{system_id}/#{folder}/"

    objects =
      S3.list_objects_v2(bucket, prefix: path)
      |> ExAws.stream!()
      |> Stream.map(fn object -> object.key end)
      |> Enum.to_list()

    S3.delete_all_objects(bucket, objects)
    |> ExAws.request!()
  end

  def nuke_system_avatars!(system_id) do
    bucket = Application.fetch_env!(:waffle, :bucket)
    path = "uploads/avatars/#{system_id}/"

    objects =
      S3.list_objects_v2(bucket, prefix: path)
      |> ExAws.stream!()
      |> Stream.map(fn object -> object.key end)
      |> Enum.to_list()

    S3.delete_all_objects(bucket, objects)
    |> ExAws.request!()
  end

  def migrate_data do
    all_users =
      Octocon.OldRepo.query!("SELECT json_agg(u) FROM (SELECT * FROM users) u").rows
      |> List.first()
      |> List.first()
      |> Enum.map(fn %{
        "apple_id" => apple_id,
        "avatar_url" => avatar_url,
        "description" => description,
        "discord_id" => discord_id,
        "discord_settings" => discord_settings,
        "email" => email,
        "encryption_initialized" => encryption_initialized,
        "encryption_key_checksum" => encryption_key_checksum,
        "fields" => fields,
        "google_id" => google_id,
        "id" => id,
        "inserted_at" => inserted_at,
        "lifetime_alter_count" => lifetime_alter_count,
        "primary_front" => primary_front,
        "salt" => salt,
        "updated_at" => updated_at,
        "username" => username
      } ->
        discord_settings = case discord_settings do
          nil -> nil
          settings ->
            %{
              system_tag: settings["system_tag"],
              show_system_tag: settings["show_system_tag"],
              case_insensitive_proxies: settings["case_insensitive_proxies"],
              show_pronouns: settings["show_pronouns"],
              ids_as_proxies: settings["ids_as_proxies"],
              silent_proxying: settings["silent_proxying"],
              use_proxy_delay: settings["use_proxy_delay"],
              global_autoproxy_mode: String.to_atom(settings["global_autoproxy_mode"]),
              global_latched_alter: settings["global_latched_alter"],
              server_settings: Enum.map(settings["server_settings"] || [], fn ss ->
                %{
                  guild_id: ss["guild_id"],
                  proxying_disabled: ss["proxying_disabled"],
                  autoproxy_mode: String.to_atom(ss["autoproxy_mode"]),
                  latched_alter: ss["latched_alter"]
                }
              end)
            }
        end
        fields = Enum.map(fields || [], fn field ->
          %{
            id: field["id"],
            name: field["name"],
            type: String.to_atom(field["type"]),
            security_level: String.to_atom(field["security_level"]),
            locked: field["locked"]
          }
        end)

        %{
          apple_id: apple_id,
          avatar_url: avatar_url,
          description: description,
          discord_id: discord_id,
          discord_settings: discord_settings,
          email: email,
          encryption_initialized: encryption_initialized,
          encryption_key_checksum: encryption_key_checksum,
          fields: fields,
          google_id: google_id,
          id: id,
          inserted_at: NaiveDateTime.from_iso8601!(inserted_at),
          lifetime_alter_count: lifetime_alter_count,
          primary_front: primary_front,
          salt: salt,
          updated_at: NaiveDateTime.from_iso8601!(updated_at),
          username: username
        }
      end)

    all_users
    |> Enum.chunk_every(500)
    |> Enum.each(fn user_batch ->
      Octocon.Repo.insert_all_global(
        Octocon.Accounts.UserRegistry,
        Enum.map(user_batch, fn user ->
          %{
            user_id: user.id,
            discord_id: user.discord_id,
            email: user.email,
            username: user.username,
            apple_id: user.apple_id,
            google_id: user.google_id,
            region: "nam",
            inserted_at: user.inserted_at,
            updated_at: NaiveDateTime.utc_now()
          }
        end)
      )
      Octocon.Repo.insert_all_regional(
        Octocon.Accounts.User,
        user_batch,
        {:region, :nam}
      )
    end)

    all_alters =
      Octocon.OldRepo.query!("SELECT json_agg(a) FROM (SELECT * FROM alters) a").rows
      |> List.first()
      |> List.first()
      |> Enum.map(fn %{
        "user_id" => user_id,
        "id" => id,
        "name" => name,
        "pronouns" => pronouns,
        "description" => description,
        "alias" => aliaz,
        "security_level" => security_level,
        "avatar_url" => avatar_url,
        "extra_images" => extra_images,
        "color" => color,
        "untracked" => untracked,
        "archived" => archived,
        "pinned" => pinned,
        "last_fronted" => last_fronted,
        "discord_proxies" => discord_proxies,
        "proxy_name" => proxy_name,
        "fields" => fields,
        "inserted_at" => inserted_at,
        "updated_at" => updated_at
      } ->
        fields = Enum.map(fields || [], fn field ->
          %{
            id: field["id"],
            name: field["name"],
          }
        end)

        %{
          user_id: user_id,
          id: id,
          name: name,
          pronouns: pronouns,
          description: description,
          alias: aliaz,
          security_level: String.to_atom(security_level),
          avatar_url: avatar_url,
          extra_images: extra_images,
          color: color,
          untracked: untracked,
          archived: archived,
          pinned: pinned,
          last_fronted: if(last_fronted, do: NaiveDateTime.from_iso8601!(last_fronted), else: nil),
          discord_proxies: discord_proxies,
          proxy_name: proxy_name,
          fields: fields,
          inserted_at: NaiveDateTime.from_iso8601!(inserted_at),
          updated_at: NaiveDateTime.from_iso8601!(updated_at)
        }
      end)

    all_alters
    |> Enum.chunk_every(500)
    |> Enum.each(fn alter_batch ->
      Octocon.Repo.insert_all_regional(
        Octocon.Alters.Alter,
        alter_batch,
        {:region, :nam}
      )
    end)
  end
end
