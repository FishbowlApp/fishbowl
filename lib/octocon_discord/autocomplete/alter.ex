defmodule OctoconDiscord.Autocomplete.Alter do
  @moduledoc false

  use OctoconDiscord.Autocomplete

  require Logger

  def cache_function(user) do
    alters =
      Octocon.Alters.get_alters_by_id({:system, user.id}, [:id, :name, :alias])
      |> Enum.map(fn %{id: id, name: name, alias: aliaz} ->
        id_suffix = " (#{id})"
        remaining_length = 100 - byte_size(id_suffix)

        display_name =
          ((name || "Unnamed alter")
           |> String.trim()
           |> String.slice(0..remaining_length)) <> id_suffix

        res = %{id: {id, display_name}, name: format_name_for_search(display_name), alter_id: id}

        if aliaz == nil do
          res
        else
          res |> Map.put(:alias, aliaz)
        end
      end)

    case alters do
      [] ->
        {:ignore, nil}

      _ ->
        {time, index} =
          :timer.tc(fn ->
            Search.new(fields: [:name, :alter_id, :alias]) |> Search.add!(alters)
          end)

        Logger.info("Built alter autocomplete index for user #{user.id} in #{time} µs")
        {:commit, index}
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
