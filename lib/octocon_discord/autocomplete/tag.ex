defmodule OctoconDiscord.Autocomplete.Tag do
  @moduledoc false

  use OctoconDiscord.Autocomplete

  def cache_function(user) do
    tags =
      Octocon.Tags.get_tags({:system, user.id})
      |> Enum.map(fn %{id: id, name: name} ->
        # [TODO]: Handle duplicates

        display_name =
          name
          |> String.trim()
          |> String.slice(0..100)

        {format_name_for_search(display_name), {id, display_name}}
      end)

    case tags do
      [] ->
        {:ignore, nil}

      _ ->
        {:commit, Radix.new(tags)}
    end
  end

  def handle_interaction(discord_id, focused_option, _interaction) do
    case focused_option do
      %{name: name, value: prefix} when name in ["tag", "parent_tag"] ->
        get_autocomplete_responses(discord_id, prefix)

      %{name: "alter", value: prefix} ->
        OctoconDiscord.Autocomplete.Alter.get_autocomplete_responses(discord_id, prefix)

      _ ->
        []
    end
  end
end
