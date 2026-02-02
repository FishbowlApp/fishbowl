defmodule OctoconDiscord.Components.AlterPaginator do
  @moduledoc false
  use OctoconDiscord.Components.Paginator,
    noun: "alter",
    interaction_id: "alter-pag",
    create_command: "alter create",
    list_command: "alter list"

  def generate_page(
        page_alters,
        %{
          items_length: alters_length,
          current_page: current_page,
          total_pages: total_pages
        }
      ) do
    container(
      [
        text(
          "## Your alters (#{alters_length})\n\nClick an alter's button to view more details."
        ),
        separator(spacing: :large),
        Enum.map(page_alters, fn alter ->
          [
            section(
              [
                text("""
                **#{alter.name || "Unnamed alter"}**#{case alter.pronouns do
                  nil -> ""
                  pronouns -> " (#{pronouns})"
                end}
                - ID: `#{alter.id}`#{case alter.alias do
                  nil -> ""
                  alias -> "  •  Alias: `#{alias}`"
                end}
                #{case alter.discord_proxies do
                  [] -> ""
                  nil -> ""
                  proxies -> "- Proxies: #{Enum.map_join(proxies, "  •  ", fn proxy -> "`#{proxy}`" end)}"
                end}
                """)
              ],
              button(
                "alter|view|#{alter.id}",
                :secondary,
                emoji: %{name: "open", id: 1_464_866_849_052_426_252}
              )
            )
          ]
        end),
        if total_pages > 1 do
          [
            separator(spacing: :large),
            text("Page #{current_page}/#{total_pages}")
          ]
        else
          []
        end
      ]
      |> List.flatten()
    )
  end

  def map_items(alters) do
    alters
    |> Enum.map(fn alter ->
      Map.take(alter, [:id, :name, :pronouns, :discord_proxies, :alias])
    end)
  end

  def generate_extra_data(_alters), do: nil
end
