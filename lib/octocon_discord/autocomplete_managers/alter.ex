defmodule OctoconDiscord.AutocompleteManagers.Alter do
  @moduledoc false

  @timeout :timer.seconds(5)

  import Cachex.Spec

  require Logger

  use OctoconDiscord.AutocompleteManagers

  def cache_function(user) do
    alters =
      Octocon.Alters.get_alters_by_id({:system, user.id}, [:id, :name])
      |> Enum.map(fn %{id: id, name: name} ->
        id_suffix = " (#{id})"
        remaining_length = 100 - byte_size(id_suffix)

        display_name =
          ((name || "Unnamed alter")
           |> String.trim()
           |> String.slice(0..remaining_length)) <> id_suffix

        {format_name_for_search(display_name), {id, display_name}}
      end)

    case alters do
      [] ->
        {:ignore, nil}

      _ ->
        trie = Radix.new(alters)
        {:commit, trie}
    end
  end

  def handle_interaction(discord_id, focused_option, _interaction) do
    case focused_option do
      %{name: "id", value: prefix} ->
        get_autocomplete_responses(discord_id, prefix)

      _ ->
        []
    end
  end
end
