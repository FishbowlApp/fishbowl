defmodule OctoconDiscord.Utils.Components do
  alias Octocon.Accounts

  alias OctoconDiscord.Utils
  alias OctoconDiscord.Utils.Emojis

  import OctoconDiscord.Utils.CV2

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
              text("**Security level:** #{Utils.security_level_to_string(alter.security_level)}"),
              text("**Created:** <t:#{inserted_at}:F> (<t:#{inserted_at}:R>)")
              # **Last updated:** <t:#{updated_at}:F> (<t:#{updated_at}:R>)
            ]
          end
        ]
        |> List.flatten(),
        %{accent_color: Utils.hex_to_int(alter.color)}
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
        action_row([])

        []
      else
        []
      end
    ]
    |> List.flatten()
  end

  def tag_component(tag, alters, guarded \\ false) do
    normalized_description =
      (tag.description || "")
      |> String.replace("\\n", "\n")
      |> String.trim()

    description =
      case String.length(normalized_description) do
        0 ->
          "*This tag does not have a description.*"

        length when length > 1500 ->
          normalized_description
          |> String.slice(0..1500)
          |> Kernel.<>("\n...")

        _ ->
          normalized_description
      end

    upper_text =
      [
        text("## #{tag.name || "Unnamed tag"}"),
        text("#{description}")
      ]

    inserted_at =
      tag.inserted_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()

    [
      container(
        [
          upper_text,
          separator(spacing: :large),
          text("""
          **Short ID:** `#{String.slice(tag.id, 0..7)}`
          """),
          case tag.parent_tag_id do
            nil ->
              []

            parent_tag_id ->
              case Octocon.Tags.get_tag({:system, tag.user_id}, parent_tag_id) do
                nil ->
                  []

                parent_tag ->
                  tag_text = text("**Parent tag:** #{parent_tag.name}")

                  if guarded do
                    [tag_text]
                  else
                    section(
                      [text("**Parent tag:** #{parent_tag.name}")],
                      button(
                        "tag|view|#{parent_tag.id}",
                        :secondary,
                        emoji: Emojis.component_emoji(Emojis.open())
                      )
                    )
                  end
              end
          end,
          if alters == [] do
            text("**Alters**: None")
          else
            filtered_alters =
              if guarded do
                Enum.filter(alters, fn alter -> alter.security_level == :public end)
              else
                alters
              end

            if filtered_alters == [] do
              text("**Alters:** None")
            else
              text("""
              **Alters:**\n#{filtered_alters |> Enum.sort_by(& &1.name) |> Enum.map_join("\n",
              fn alter -> "- #{alter.name}#{if alter.pronouns && alter.pronouns != "", do: " (#{alter.pronouns})", else: ""}" end)}
              """)
            end
          end,
          if guarded do
            []
          else
            [
              separator(spacing: :large),
              text("**Security level:** #{Utils.security_level_to_string(tag.security_level)}"),
              text("**Created:** <t:#{inserted_at}:F> (<t:#{inserted_at}:R>)")
              # **Last updated:** <t:#{updated_at}:F> (<t:#{updated_at}:R>)
            ]
          end
        ]
        |> List.flatten(),
        %{accent_color: Utils.hex_to_int(tag.color)}
      )
    ]
    |> List.flatten()
  end
end
