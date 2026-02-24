defmodule OctoconDiscord.Autocomplete.FriendRequest do
  @moduledoc false

  use OctoconDiscord.Autocomplete

  def cache_function(user, :incoming) do
    requests =
      Octocon.Friendships.incoming_friend_requests({:system, user.id})
      |> Enum.map(fn %{from: %{id: friend_id, username: username}} ->
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

        %{id: {friend_id, display_name}, name: format_name_for_search(display_name)}
      end)

    case requests do
      [] ->
        {:ignore, nil}

      _ ->
        {:commit, Search.new(fields: [:name]) |> Search.add!(requests)}
    end
  end

  def cache_function(user, :outgoing) do
    requests =
      Octocon.Friendships.outgoing_friend_requests({:system, user.id})
      |> Enum.map(fn %{to: %{id: friend_id, username: username}} ->
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

        %{id: {friend_id, display_name}, name: format_name_for_search(display_name)}
      end)

    case requests do
      [] ->
        {:ignore, nil}

      _ ->
        {:commit, Search.new(fields: [:name]) |> Search.add!(requests)}
    end
  end

  def handle_interaction(discord_id, focused_option, %{data: %{options: options}}) do
    incoming_commands = ~w[accept reject]

    [%{options: [%{name: command_name} | []]}] = options

    case focused_option do
      %{name: "system-id", value: prefix} ->
        is_incoming = command_name in incoming_commands
        supplementary_key = if is_incoming, do: :incoming, else: :outgoing

        get_autocomplete_responses({discord_id, supplementary_key}, prefix)

      _ ->
        []
    end
  end
end
