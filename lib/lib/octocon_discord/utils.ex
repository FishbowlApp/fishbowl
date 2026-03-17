defmodule OctoconDiscord.Utils do
  @moduledoc """
  Various utility functions for Octocon's Discord frontend.
  """

  require Logger

  alias Nostrum.Api
  alias Octocon.Accounts
  alias Octocon.Accounts.User

  alias OctoconDiscord.Utils.{
    Commands,
    Components,
    CV2
  }

  @alias_regex ~r/^(?![\s\d])[^\n]{1,80}$/

  def get_cached_guild(id),
    do: wrap_cache_call(id, &Nostrum.Cache.GuildCache.get/1, &Api.Guild.get/1)

  defp wrap_cache_call(id, cache_function, api_function) do
    case cache_function.(id) do
      {:ok, data} ->
        # Logger.debug("Discord guild cache hit")
        data

      {:error, _} ->
        # Logger.debug("Discord guild cache miss")
        {:ok, api_result} = api_function.(id)
        api_result
    end
  end

  def parse_id!(id) when is_integer(id), do: id
  def parse_id!(id) when is_binary(id), do: Integer.parse(id) |> elem(0)

  def alter_id_valid?(id) when is_integer(id) and id > 0 and id < 32_768, do: true

  def alter_id_valid?(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} when int > 0 and int < 32_768 -> true
      _ -> false
    end
  end

  def alter_id_valid?(_), do: false

  def alter_alias_valid?(aliaz), do: String.match?(aliaz, @alias_regex)

  def validate_alter_id(alter_id, callback) do
    if alter_id_valid?(alter_id) do
      callback.()
    else
      Components.error_component("You don't have an alter with ID **#{alter_id}**.")
    end
  end

  def validate_alias(aliaz) do
    if String.match?(aliaz, @alias_regex) do
      {:alias, aliaz}
    else
      {:error,
       "Invalid alias. An alias must meet the following criteria:\n\n- Between 1-80 characters\n- Cannot consist of just a number\n-Cannot start with a space"}
    end
  end

  def parse_idalias(idalias, allow_nil \\ false) do
    if idalias == nil or String.trim(idalias) == "" do
      if allow_nil do
        nil
      else
        {:error, "You must provide an alter ID (or alias) to use this command."}
      end
    else
      if alter_id_valid?(idalias) do
        {:id, parse_id!(idalias)}
      else
        validate_alias(idalias)
      end
    end
  end

  def with_id_or_alias(options_or_idalias, callback, allow_nil \\ false)

  def with_id_or_alias(options, callback, allow_nil) when is_list(options) do
    idalias = Commands.get_command_option(options, "id")

    with_id_or_alias(to_string(idalias), callback, allow_nil)
  end

  def with_id_or_alias(idalias, callback, allow_nil) when is_binary(idalias) do
    case parse_idalias(idalias, allow_nil) do
      {:error, error} -> Components.error_component(error)
      result -> callback.(result)
    end
  end

  def get_avatar_url(discord_id, avatar_hash),
    do: "https://cdn.discordapp.com/avatars/#{discord_id}/#{avatar_hash}.png"

  def hex_to_int(nil), do: hex_to_int("#3F3793")

  def hex_to_int(hex) do
    hex
    |> String.downcase()
    |> String.replace_leading("#", "")
    |> String.to_integer(16)
  end

  def validate_hex_color(color) do
    if String.match?(color, ~r/^#?[0-9A-Fa-f]{6}$/i) do
      {:ok, String.replace_leading(color, "#", "") |> String.upcase()}
    else
      :error
    end
  end

  def send_dm(%User{} = user, title, message) do
    spawn(fn ->
      Octocon.ClusterUtils.run_on_primary(fn ->
        unless user.discord_id == nil do
          {:ok, channel} = Api.User.create_dm(Integer.parse(user.discord_id) |> elem(0))

          Api.Message.create(channel.id, %{
            components: [
              CV2.container(
                [
                  CV2.text("### #{title}"),
                  CV2.text(message)
                ],
                %{accent_color: hex_to_int("#3F3793")}
              )
            ],
            flags: CV2.cv2_flags(false)
          })
        end
      end)
    end)
  end

  def send_dm(system_identity, title, message) do
    user = Accounts.get_user!(system_identity)
    send_dm(user, title, message)
  end

  def send_dm(%User{} = user, options) do
    spawn(fn ->
      unless user.discord_id == nil do
        {:ok, channel} = Api.User.create_dm(Integer.parse(user.discord_id) |> elem(0))

        Api.Message.create(channel.id, options)
      end
    end)
  end

  def send_dm(system_identity, options) when is_map(options) do
    user = Accounts.get_user!(system_identity)
    send_dm(user, options)
  end

  def get_guild_data do
    Nostrum.Cache.GuildCache.fold([], fn guild, acc ->
      [
        %{
          name: guild.name,
          member_count: guild.member_count,
          id: guild.id
        }
        | acc
      ]
    end)
    |> Enum.sort_by(& &1.member_count, :desc)
  end

  def security_level_to_string(nil), do: "Unknown"
  def security_level_to_string(:private), do: "Private"
  def security_level_to_string(:trusted_only), do: "Trusted friends only"
  def security_level_to_string(:friends_only), do: "Friends only"
  def security_level_to_string(:public), do: "Public"
end
