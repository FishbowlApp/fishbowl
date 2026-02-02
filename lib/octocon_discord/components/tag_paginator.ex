defmodule OctoconDiscord.Components.TagPaginator do
  @moduledoc false
  use OctoconDiscord.Components.Paginator,
    noun: "tag",
    interaction_id: "tag-pag",
    create_command: "tag create",
    list_command: "tag list"

  alias OctoconDiscord.Utils.Emojis

  def generate_page(
        page_tags,
        %{
          items_length: tags_length,
          current_page: current_page,
          total_pages: total_pages
        }
      ) do
    container(
      [
        text("## Your tags (#{tags_length})\n\nClick a tag's button to view more details."),
        separator(spacing: :large),
        Enum.map(page_tags, fn tag ->
          [
            section(
              [
                text("""
                **#{tag.name || "Unnamed tag"}**
                """)
              ],
              button(
                "tag|view|#{tag.id}",
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

  def map_items(tags) do
    tags =
      Enum.map(tags, fn tag ->
        Map.take(tag, [:id, :name, :description, :color, :security_level, :parent_tag_id])
      end)

    valid_ids =
      tags
      |> Enum.map(& &1.id)
      |> MapSet.new()

    tags =
      Enum.map(tags, fn tag ->
        if is_nil(tag.parent_tag_id) or MapSet.member?(valid_ids, tag.parent_tag_id) do
          tag
        else
          %{tag | parent_tag_id: nil}
        end
      end)

    children =
      Enum.group_by(tags, & &1.parent_tag_id)

    children
    |> Map.get(nil, [])
    |> Enum.sort_by(& &1.name)
    |> Enum.flat_map(&flatten(&1, children, 0))
  end

  defp flatten(tag, children_map, depth) do
    prefix = String.duplicate("⎯", depth) <> if depth > 0, do: ">", else: ""

    current =
      Map.update!(tag, :name, fn name ->
        "#{prefix} #{name}" |> String.trim()
      end)

    children_map
    |> Map.get(tag.id, [])
    |> Enum.sort_by(& &1.name)
    |> Enum.flat_map(&flatten(&1, children_map, depth + 1))
    |> then(&[current | &1])
  end

  def generate_extra_data(_tags), do: nil
end
