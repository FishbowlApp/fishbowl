defmodule OctoconDiscord.Autocomplete.Friend do
  @moduledoc false

  use OctoconDiscord.Autocomplete

  def cache_function(user) do
    friends =
      Octocon.Friendships.list_friendships({:system, user.id})
      |> Enum.map(fn %{friend: %{id: friend_id, username: username}} ->
        display_name =
          if username == nil do
            friend_id
          else
            id_suffix = " (#{friend_id})"
            remaining_length = 100 - byte_size(id_suffix)

            (username
             |> String.trim()
             |> String.slice(0..remaining_length)) <> id_suffix
          end

        {format_name_for_search(display_name), {friend_id, display_name}}
      end)

    case friends do
      [] ->
        {:ignore, nil}

      _ ->
        {:commit, Radix.new(friends)}
    end
  end

  def handle_interaction(discord_id, focused_option, _interaction) do
    case focused_option do
      %{name: "system-id", value: prefix} ->
        get_autocomplete_responses(discord_id, prefix)

      _ ->
        []
    end
  end
end
