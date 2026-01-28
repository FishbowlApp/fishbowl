defmodule OctoconDiscord.Utils do
  @moduledoc """
  Various utility functions for Octocon's Discord frontend.
  """

  require Logger

  alias Nostrum.Api
  # alias Nostrum.Cache.GuildCache
  alias Octocon.Accounts
  alias Octocon.Accounts.User

  @alias_regex ~r/^(?![\s\d])[^\n]{1,80}$/

  # [TODO] Replace `get_from_guild_cache/1` with `Nostrum.Cache.GuildCache.get/1`
  # Blocked by: https://github.com/Kraigie/nostrum/pull/622
  def get_cached_guild(id),
    do: wrap_cache_call(id, &Nostrum.Cache.GuildCache.get/1, &Api.Guild.get/1)

  # defp get_from_guild_cache(id) do
  #   case :mnesia.activity(:sync_transaction, fn -> :mnesia.read(:nostrum_guilds, id) end) do
  #     [{_tag, _id, guild}] -> {:ok, guild}
  #     _ -> {:error, nil}
  #   end
  # end

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

  def get_command_option(options, name) do
    case Enum.find(options, fn %{name: option} -> option == name end) do
      nil -> nil
      option -> Map.get(option, :value)
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
      error_component("You don't have an alter with ID **#{alter_id}**.")
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
    idalias = get_command_option(options, "id")

    with_id_or_alias(to_string(idalias), callback, allow_nil)
  end

  def with_id_or_alias(idalias, callback, allow_nil) when is_binary(idalias) do
    case parse_idalias(idalias, allow_nil) do
      {:error, error} -> error_component(error)
      result -> callback.(result)
    end
  end

  def register_message,
    do:
      error_component(
        "You're not registered. Use the `/register` command or link your Discord account to your existing system."
      )

  def ensure_registered(discord_id, callback) do
    if Accounts.user_exists?({:discord, discord_id}) do
      callback.()
    else
      register_message()
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

  def error_component_raw(error) do
    container(
      [
        text("### :x: Whoops!"),
        text(error)
      ],
      %{
        accent_color: 0xFF0000
      }
    )
  end

  def error_component(error, ephemeral? \\ true),
    do: [
      components: [error_component_raw(error)],
      flags: cv2_flags(ephemeral?)
    ]

  def success_component_raw(success) do
    container(
      [
        text("### :white_check_mark: Success!"),
        text(success)
      ],
      %{
        accent_color: 0x00FF00
      }
    )
  end

  def success_component(success, ephemeral? \\ true),
    do: [
      components: [success_component_raw(success)],
      flags: cv2_flags(ephemeral?)
    ]

  def system_component_raw(system, self?) do
    discord_settings = system.discord_settings || %Accounts.DiscordSettings{}

    normalized_description =
      (system.description || "")
      |> String.replace("\\n", "\n")
      |> String.trim()

    description =
      case String.length(normalized_description) do
        0 ->
          "*This system does not have a description.*"

        length when length > 1500 ->
          normalized_description
          |> String.slice(0..1500)
          |> Kernel.<>("\n...")

        _ ->
          normalized_description
      end

    upper_text = "## Information for <@#{system.discord_id}>\n\n#{description}"

    container(
      [
        case system.avatar_url do
          url when url != nil and url != "" ->
            section([upper_text], thumbnail(url))

          _ ->
            text(upper_text)
        end,
        separator(spacing: :large),
        text("**ID:** `#{system.id}`"),
        text("**Username:** #{if system.username, do: system.username, else: "None"}"),
        text(
          "**Discord:** #{if system.discord_id, do: "<@#{system.discord_id}>", else: "Not linked"}"
        ),
        if self? do
          [
            separator(spacing: :large),
            text("**Email linked:** #{if system.email, do: "Yes", else: "No"}"),
            text(
              "**System tag:** #{if discord_settings.system_tag, do: discord_settings.system_tag, else: "None"}"
            )
          ]
        else
          []
        end
      ]
      |> List.flatten()
    )
  end

  def system_component(system, self?) do
    [
      components: [system_component_raw(system, self?)],
      flags: cv2_flags()
    ]
  end

  def alter_component(alter, fronts, guarded \\ false) do
    normalized_description =
      (alter.description || "")
      |> String.replace("\\n", "\n")
      |> String.trim()

    description =
      case String.length(normalized_description) do
        0 ->
          "*This alter does not have a description.*"

        length when length > 1500 ->
          normalized_description
          |> String.slice(0..1500)
          |> Kernel.<>("\n...")

        _ ->
          normalized_description
      end

    show_extra_components = fronts != false and not guarded

    is_fronting =
      show_extra_components and alter.id in (fronts |> Enum.map(& &1.front.alter_id))

    is_primary =
      show_extra_components and
        alter.id ==
          fronts
          |> Enum.find(fn f -> f.primary end)
          |> case do
            nil -> nil
            front -> front.front.alter_id
          end

    fronting_text =
      cond do
        not is_fronting ->
          nil

        is_primary ->
          "\n\n⏫  •  Currently fronting! (Main)"

        true ->
          "\n\n⬆️  •  Currently fronting!"
      end

    upper_text =
      [
        text(
          "## #{alter.name || "Unnamed alter"}#{if alter.pronouns && alter.pronouns != "", do: " (#{alter.pronouns})", else: ""}"
        ),
        if(fronting_text != nil, do: text(fronting_text), else: []),
        text("#{description}")
      ]
      |> List.flatten()

    [
      container(
        [
          case alter.avatar_url do
            url when url != nil and url != "" ->
              section(upper_text, thumbnail(url))

            _ ->
              upper_text
          end,
          separator(spacing: :large),
          text("""
          **ID:** `#{alter.id}`#{case alter.alias do
            nil -> ""
            alias -> "  •  **Alias:** `#{alias}`"
          end}
          """),
          case alter.proxy_name do
            nil ->
              []

            "" ->
              []

            proxy_name ->
              text("**Proxy name:** #{proxy_name}")
          end,
          text("""
          **Proxies:**\n#{case alter.discord_proxies do
            [] -> "None"
            nil -> "None"
            proxies -> Enum.map_join(proxies, "\n", fn proxy -> "- `#{proxy}`" end)
          end}
          """),
          if guarded do
            []
          else
            inserted_at =
              alter.inserted_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()

            # updated_at = alter.updated_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()

            [
              separator(spacing: :large),
              text("**Security level:** #{security_level_to_string(alter.security_level)}"),
              text("**Created:** <t:#{inserted_at}:F> (<t:#{inserted_at}:R>)")
              # **Last updated:** <t:#{updated_at}:F> (<t:#{updated_at}:R>)
            ]
          end
        ]
        |> List.flatten(),
        %{accent_color: hex_to_int(alter.color)}
      ),
      cond do
        !show_extra_components ->
          []

        is_fronting ->
          primary_command = if is_primary, do: "removeprimary", else: "setprimary"

          action_row([
            button("alter|removefront|#{alter.id}", :secondary,
              label: "Remove from front",
              emoji: %{name: "⬇️"}
            ),
            button("alter|#{primary_command}|#{alter.id}", :secondary,
              label: if(is_primary, do: "Unset as main front", else: "Set as main front"),
              emoji: %{name: if(is_primary, do: "⏬", else: "⏫")}
            )
          ])

        true ->
          action_row([
            button("alter|addfront|#{alter.id}", :secondary,
              label: "Add to front",
              emoji: %{name: "⬆️"}
            ),
            button("alter|setfront|#{alter.id}", :secondary,
              label: "Set as front",
              emoji: %{name: "📍"}
            )
          ])
      end,
      if show_extra_components do
        action_row([

        ])

        []
        else [] end
    ]
    |> List.flatten()
  end

  def send_dm(%User{} = user, title, message) do
    spawn(fn ->
      Octocon.ClusterUtils.run_on_primary(fn ->
        unless user.discord_id == nil do
          {:ok, channel} = Api.User.create_dm(Integer.parse(user.discord_id) |> elem(0))

          Api.Message.create(channel.id, %{
            components: [
              container(
                [
                  text("### #{title}"),
                  text(message)
                ],
                %{accent_color: hex_to_int("#3F3793")}
              )
            ],
            flags: cv2_flags(false)
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

  def system_id_from_opts(opts, callback) do
    num_opts = Enum.count(Map.keys(opts))
    num_nil = Map.values(opts) |> Enum.count(&is_nil/1)

    cond do
      num_nil == num_opts ->
        error_component("You must specify a system ID, Discord ping, or username.")

      num_nil != num_opts - 1 ->
        error_component("You must *only* specify a system ID, Discord ping, *or* username.")

      opts.system_id ->
        if Accounts.user_exists?({:system, opts.system_id}) do
          callback.({:system, opts.system_id}, "**#{opts.system_id}**")
        else
          error_component("A system does not exist with ID **#{opts.system_id}**.")
        end

      opts.discord_id ->
        discord_id = to_string(opts.discord_id)

        if Accounts.user_exists?({:discord, discord_id}) do
          callback.({:discord, discord_id}, "<@#{discord_id}>")
        else
          error_component("A system does not exist with that Discord account.")
        end

      opts.username ->
        case Accounts.get_user_id_by_username(opts.username) do
          nil ->
            error_component("A system does not exist with username **#{opts.username}**.")

          system_id ->
            callback.({:system, system_id}, "**#{opts.username}**")
        end

      true ->
        error_component("An unknown error occurred.")
    end
  end

  def add_show_option(options) do
    options ++
      [
        %{
          name: "show",
          description: "Show this message to the entire channel instead of just you.",
          type: :boolean,
          required: false
        }
      ]
  end

  def get_show_option(options) do
    case get_command_option(options, "show") do
      nil -> false
      value -> value
    end
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

  # Components V2

  def container(components, options \\ []) do
    %{
      type: 17,
      components: components
    }
    |> Map.merge(options |> Enum.into(%{}))
  end

  def section(components, accessory, options \\ []) do
    %{
      type: 9,
      components: components,
      accessory: accessory
    }
    |> Map.merge(options |> Enum.into(%{}))
  end

  def separator(options \\ []) do
    divider = Keyword.get(options, :divider, true)

    spacing =
      Keyword.get(options, :spacing, :small)
      |> case do
        :small -> 1
        :large -> 2
      end

    %{
      type: 14,
      divider: divider,
      spacing: spacing
    }
  end

  def thumbnail(url, options \\ []) do
    %{
      type: 11,
      media: %{url: url}
    }
    |> Map.merge(options |> Enum.into(%{}))
  end

  def action_row(components, options \\ []) do
    %{
      type: 1,
      components: components
    }
    |> Map.merge(options |> Enum.into(%{}))
  end

  def string_select(id, options_list, options \\ []) do
    %{
      type: 3,
      custom_id: id,
      options: options_list
    }
    |> Map.merge(options |> Enum.into(%{}))
  end

  def user_select(id, options \\ []) do
    %{
      type: 5,
      custom_id: id
    }
    |> Map.merge(options |> Enum.into(%{}))
  end

  def role_select(id, options \\ []) do
    %{
      type: 6,
      custom_id: id
    }
    |> Map.merge(options |> Enum.into(%{}))
  end

  def mentionable_select(id, options \\ []) do
    %{
      type: 7,
      custom_id: id
    }
    |> Map.merge(options |> Enum.into(%{}))
  end

  def channel_select(id, options \\ []) do
    %{
      type: 8,
      custom_id: id
    }
    |> Map.merge(options |> Enum.into(%{}))
  end

  def text(text, options \\ []) do
    %{
      type: 10,
      content: text
    }
    |> Map.merge(options |> Enum.into(%{}))
  end

  def button(id, style, options \\ []) do
    style =
      case style do
        :primary -> 1
        :secondary -> 2
        :success -> 3
        :danger -> 4
        :link -> 5
        :premium -> 6
        num when is_integer(num) and num in 1..6 -> num
        _ -> 2
      end

    %{
      type: 2,
      custom_id: id,
      style: style
    }
    |> Map.merge(options |> Enum.into(%{}))
  end

  def link_button(url, options \\ []) do
    %{
      type: 2,
      style: 5,
      url: url
    }
    |> Map.merge(options |> Enum.into(%{}))
  end

  def cv2_flags(ephemeral \\ true) do
    if ephemeral do
      Bitwise.bor(Bitwise.bsl(1, 15), Bitwise.bsl(1, 6))
    else
      Bitwise.bsl(1, 15)
    end
  end

  def security_level_to_string(nil), do: "Unknown"
  def security_level_to_string(:private), do: "Private"
  def security_level_to_string(:trusted_only), do: "Trusted friends only"
  def security_level_to_string(:friends_only), do: "Friends only"
  def security_level_to_string(:public), do: "Public"
end
