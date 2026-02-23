defmodule Octocon.Workers.SimplyPluralImportWorker do
  @moduledoc """
  An Oban worker that imports alters from Simply Plural into a system with the given ID.

  ## Arguments

  - `system_id` (binary): The ID of the system to import alters into.
  - `sp_token` (binary): The Simply Plural API token to use for the request.
  """

  import Octocon.Utils.Import

  require Logger

  alias Octocon.{
    Accounts,
    Alters,
    Alters.Alter,
    Tags.AlterTag,
    Tags.Tag
  }

  alias OctoconWeb.Uploaders.Avatar

  @sp_endpoint URI.parse("https://api.apparyllis.com/v1/")
  @cdn_endpoint URI.parse("https://spaces.apparyllis.com/")

  def perform(%{"system_id" => system_id, "sp_token" => sp_token}) do
    Logger.info("Performing Simply Plural import for user #{system_id}")

    %{
      "id" => id,
      "content" => %{
        "desc" => description
      }
    } = get_system_data(sp_token)

    {:ok, %{body: custom_fields_body}} = send_sp_request(:get, "/customFields/#{id}", sp_token)
    {:ok, %{body: alters_body}} = send_sp_request(:get, "/members/#{id}", sp_token)
    {:ok, %{body: groups_body}} = send_sp_request(:get, "/groups/#{id}", sp_token)

    user_region = Octocon.UserRegistryCache.get_region({:system, system_id})
    start_count = Accounts.get_user!({:system, system_id}).lifetime_alter_count + 1

    custom_fields =
      Jason.decode!(custom_fields_body)
      |> Enum.map(fn field ->
        %{
          "id" => field_id,
          "content" => %{
            "name" => name
          }
        } = field

        {field_id,
         %Octocon.Accounts.Field{
           id: Ecto.UUID.generate(),
           name: name |> default_if_empty(100, "Unnamed field"),
           type: :text,
           locked: false,
           security_level: :private
         }}
      end)

    field_associations =
      custom_fields
      |> Enum.map(fn {field_id, field} -> {field_id, field.id} end)
      |> Enum.into(%{})

    {alters, uuids, avatars} =
      Jason.decode!(alters_body)
      |> Stream.map(&{&1["content"], &1["id"]})
      |> Stream.with_index(start_count)
      |> Stream.map(fn {{alter, uuid}, index} ->
        {alter, avatar} = parse_alter(system_id, alter, index, field_associations)
        {alter, uuid, avatar}
      end)
      |> Stream.map(fn {alter, uuid, avatar} ->
        {{alter, alter_to_insert_query(alter, user_region)}, uuid, avatar}
      end)
      |> Enum.reduce({[], [], []}, fn
        {alter, uuid, nil}, {alters, uuids, avatars} ->
          {[alter | alters], [uuid | uuids], avatars}

        {alter, uuid, avatar}, {alters, uuids, avatars} ->
          {[alter | alters], [uuid | uuids], [avatar | avatars]}
      end)

    tags_response = Jason.decode!(groups_body)

    tag_ids =
      tags_response
      |> Enum.map(fn tag -> {tag["id"], Ecto.UUID.generate()} end)
      |> Enum.into(%{})

    tags =
      tags_response
      |> Stream.map(fn tag ->
        parse_tag(system_id, tag["content"], Map.get(tag_ids, tag["id"]), tag_ids)
      end)
      |> Enum.map(fn {tag, members} ->
        {
          {tag, tag_to_insert_query(tag, user_region)},
          members
        }
      end)

    alter_associations =
      uuids
      |> Enum.zip(Enum.map(alters, fn {alter, _query} -> alter.id end))
      |> Enum.into(%{})

    alter_tags =
      tags
      |> Enum.map(fn {{tag, _}, members} ->
        {
          tag.id,
          Enum.map(members, fn member -> Map.get(alter_associations, member) end)
        }
      end)
      |> Enum.map(fn {tag_id, member_ids} ->
        member_ids
        |> Enum.map(fn alter_id ->
          %AlterTag{
            user_id: system_id,
            alter_id: alter_id,
            tag_id: tag_id,
            inserted_at: NaiveDateTime.utc_now(:second) |> naive_datetime_to_datetime(),
            updated_at: NaiveDateTime.utc_now(:second) |> naive_datetime_to_datetime()
          }
          |> alter_tag_to_insert_query(user_region)
        end)
      end)
      |> List.flatten()

    alter_count = length(alters)

    alters
    |> Enum.map(fn {_alter, query} -> query end)
    |> Enum.chunk_every(500)
    |> Enum.each(fn chunk ->
      batch = %Exandra.Batch{queries: chunk}

      :ok = Exandra.execute_batch(Octocon.Repo, batch, consistency: :one)
    end)

    tags
    |> Enum.map(fn {{_tag, query}, _members} -> query end)
    |> Enum.chunk_every(500)
    |> Enum.each(fn chunk ->
      batch = %Exandra.Batch{queries: chunk}

      :ok = Exandra.execute_batch(Octocon.Repo, batch, consistency: :one)
    end)

    alter_tags
    |> Enum.chunk_every(500)
    |> Enum.each(fn chunk ->
      batch = %Exandra.Batch{queries: chunk}

      :ok = Exandra.execute_batch(Octocon.Repo, batch, consistency: :one)
    end)

    user = Accounts.get_user!({:system, system_id})

    Accounts.update_user(
      user,
      %{
        lifetime_alter_count: user.lifetime_alter_count + alter_count,
        description: default_if_empty(description, 3000, user.description)
      }
    )

    Accounts.add_bulk_fields(
      {:system, system_id},
      Enum.map(custom_fields, fn {_field_id, field} -> field end)
    )

    OctoconWeb.Endpoint.broadcast!("system:#{system_id}", "alters_created", %{
      alters:
        Enum.map(alters, fn {alter, _query} -> OctoconWeb.System.AlterJSON.data_me(alter) end)
    })

    OctoconWeb.Endpoint.broadcast!("system:#{system_id}", "sp_import_complete", %{
      alter_count: alter_count
    })

    OctoconDiscord.Utils.send_dm(
      {:system, system_id},
      "Import complete (Simply Plural)",
      "#{alter_count} alters have been successfully imported from Simply Plural. They have been assigned IDs #{start_count} - #{start_count + alter_count - 1}.\n\n**Note:** This process should only be completed once; doing it again will result in duplicate alters."
    )

    spawn(fn ->
      system_identity = {:system, system_id}
      OctoconDiscord.Cache.Proxy.invalidate(system_identity)
      OctoconDiscord.Autocomplete.invalidate_all(system_identity)
    end)

    spawn(fn ->
      Task.async_stream(
        avatars,
        fn {avatar_url, avatar_scope} ->
          case Octocon.ClusterUtils.run_on_sidecar(
                 fn -> Avatar.store({avatar_url, avatar_scope}) end,
                 timeout: 10_000
               ) do
            {:ok, _} ->
              octo_url = Avatar.url({"primary.webp", avatar_scope}, :primary)

              Alters.update_alter(
                {:system, avatar_scope.system_id},
                {:id, avatar_scope.alter_id},
                %{avatar_url: octo_url}
              )

            _ ->
              # Avatar doesn't exist; stale reference on SP's end?
              :ok
          end
        end,
        # NOTE: Potentially replace with schedulers_online on a beefier server?
        max_concurrency: 2,
        ordered: false,
        timeout: :timer.seconds(10),
        on_timeout: :kill_task
      )
      |> Stream.run()
    end)

    :ok
  rescue
    e ->
      Logger.error("Error importing Simply Plural alters")
      Logger.error(Exception.format(:error, e, __STACKTRACE__))
      {:error, e}
  end

  defp get_system_data(token) do
    {:ok, %{body: body}} = send_sp_request(:get, "/me", token)
    Jason.decode!(body)
  end

  defp send_sp_request(method, endpoint, token) do
    uri = URI.append_path(@sp_endpoint, endpoint)

    res =
      Finch.build(method, uri, [
        {"User-Agent", "Octocon/spimport; contact = contact@octocon.app"},
        {"Authorization", token}
      ])
      |> Finch.request(Octocon.Finch)

    res
  end

  defp parse_alter(system_id, alter, id, field_associations) do
    {
      %Alter{
        user_id: system_id,
        id: id,
        name: default_if_empty(alter["name"], 80, "Unnamed alter"),
        pronouns: default_if_empty(alter["pronouns"], 50),
        description: default_if_empty(alter["desc"], 3000),
        color: parse_color(alter["color"]),
        alias: nil,
        pinned: false,
        archived: false,
        untracked: false,
        last_fronted: nil,
        fields:
          Enum.map(alter["info"] || [], fn {field_id, value} ->
            octocon_field_id = Map.get(field_associations, field_id)

            value = %Octocon.Alters.Field{
              id: octocon_field_id,
              value: value
            }

            value
          end),
        security_level: 3,
        inserted_at: NaiveDateTime.utc_now(:second) |> naive_datetime_to_datetime(),
        updated_at: NaiveDateTime.utc_now(:second) |> naive_datetime_to_datetime()
      },
      if alter["avatarUuid"] != nil and String.length(alter["avatarUuid"]) != 0 do
        random_id = Nanoid.generate(30)

        avatar_url =
          @cdn_endpoint
          |> URI.merge("/avatars/#{alter["uid"]}/#{alter["avatarUuid"]}")
          |> URI.to_string()

        {
          avatar_url,
          %{
            system_id: system_id,
            alter_id: id,
            random_id: random_id
          }
        }
      else
        nil
      end
    }
  end

  defp parse_tag(system_id, tag, tag_id, tag_ids) do
    {%Tag{
       user_id: system_id,
       id: tag_id,
       name: default_if_empty(tag["name"], 100, "Unnamed tag"),
       description: default_if_empty(tag["desc"], 1000),
       color: parse_color(tag["color"]),
       security_level: 3,
       parent_tag_id:
         case tag["parent"] do
           nil -> nil
           "root" -> nil
           parent_id -> Map.get(tag_ids, parent_id)
         end,
       inserted_at: NaiveDateTime.utc_now(:second) |> naive_datetime_to_datetime(),
       updated_at: NaiveDateTime.utc_now(:second) |> naive_datetime_to_datetime()
     }, tag["members"]}
  end

  defp default_if_empty(string, max, default \\ nil)

  defp default_if_empty(nil, _max, default), do: default
  defp default_if_empty(string, _max, default) when string == "", do: default
  defp default_if_empty(string, max, _default), do: string |> String.slice(0..max)

  defp parse_color("#" <> _ = color) when byte_size(color) == 7, do: color
  defp parse_color(color) when byte_size(color) == 6, do: color
  defp parse_color(color) when color == "", do: nil
  defp parse_color(nil), do: nil
end
