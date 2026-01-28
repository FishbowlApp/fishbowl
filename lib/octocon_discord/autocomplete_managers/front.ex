defmodule OctoconDiscord.AutocompleteManagers.Front do
  @moduledoc false

  use OctoconDiscord.AutocompleteManagers

  def cache_function(user) do
    fronting =
      Octocon.Fronts.currently_fronting({:system, user.id})
      |> Enum.map(fn %{alter: %{id: id, name: name}} ->
        id_suffix = " (#{id})"
        remaining_length = 100 - byte_size(id_suffix)

        display_name =
          ((name || "Unnamed alter")
           |> String.trim()
           |> String.slice(0..remaining_length)) <> id_suffix

        {format_name_for_search(display_name), {id, display_name}}
      end)

    case fronting do
      [] ->
        {:ignore, nil}

      _ ->
        {:commit, Radix.new(fronting)}
    end
  end

  def handle_interaction(discord_id, focused_option, %{data: %{options: [%{name: command} | _]}}) do
    autocomplete_provider =
      if command in ["add", "set"] do
        fn prefix ->
          currently_fronting =
            get_autocomplete_responses(discord_id, "") |> Enum.map(& &1.value)

          OctoconDiscord.AutocompleteManagers.Alter.get_autocomplete_responses(
            discord_id,
            prefix
          )
          |> Enum.filter(fn %{value: alter_id} -> alter_id not in currently_fronting end)
        end
      else
        fn prefix -> get_autocomplete_responses(discord_id, prefix) end
      end

    case focused_option do
      %{name: "id", value: prefix} ->
        autocomplete_provider.(prefix)

      _ ->
        []
    end
  end
end
