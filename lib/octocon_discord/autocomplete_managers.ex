defmodule OctoconDiscord.AutocompleteManagers do
  @moduledoc false

  use Supervisor

  require Logger

  @manager_associations %{
    "alter" => OctoconDiscord.AutocompleteManagers.Alter,
    "friend" => OctoconDiscord.AutocompleteManagers.Friend,
    "request" => OctoconDiscord.AutocompleteManagers.FriendRequest,
    "front" => OctoconDiscord.AutocompleteManagers.Front
  }

  def start_link(_), do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  def init([]) do
    children = [
      OctoconDiscord.AutocompleteManagers.Alter,
      OctoconDiscord.AutocompleteManagers.Friend,
      OctoconDiscord.AutocompleteManagers.FriendRequest,
      OctoconDiscord.AutocompleteManagers.Front
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defmacro __using__(_opts) do
    quote do
      import Cachex.Spec

      use Octocon.CachexChild,
        name: __MODULE__,
        hooks: [
          hook(
            module: Cachex.Limit.Scheduled,
            args: {2000, [], [frequency: :timer.seconds(30)]}
          )
        ],
        expiration: expiration(default: :timer.minutes(5))

      import OctoconDiscord.AutocompleteManagers,
        only: [format_name_for_search: 1, generate_autocomplete_responses: 2]

      @timeout :timer.seconds(5)

      def get_autocomplete_responses(discord_id, prefix)
          when (is_binary(discord_id) or is_tuple(discord_id)) and is_binary(prefix) and
                 byte_size(prefix) <= 20 do
        Task.async(fn -> do_fetch(discord_id, prefix) end)
        |> Task.await(@timeout)
      end

      defp do_fetch(key, prefix) do
        trie =
          Cachex.fetch!(
            __MODULE__,
            key,
            OctoconDiscord.AutocompleteManagers.wrap_cache_function(__MODULE__, is_tuple(key))
          )

        if trie == nil do
          []
        else
          generate_autocomplete_responses(trie, prefix)
        end
      end

      def invalidate(system_identity, supplementary \\ nil)

      def invalidate({:discord, discord_id}, nil) when is_binary(discord_id) do
        delete_cache_key(discord_id)
      end

      def invalidate({:discord, discord_id}, supplementary) when is_binary(discord_id) do
        delete_cache_key({discord_id, supplementary})
      end

      def invalidate(system_identity, supplementary) do
        case Octocon.Accounts.get_user(system_identity) do
          %{discord_id: discord_id} when discord_id != nil ->
            invalidate({:discord, discord_id}, supplementary)

          _ ->
            {:ok, true}
        end
      end

      defp delete_cache_key(key) do
        Octocon.ClusterUtils.run_on_all_primary_nodes(fn ->
          Cachex.del(__MODULE__, key)
        end)
      end
    end
  end

  def generate_autocomplete_responses(trie, prefix, id_type \\ :string)
      when is_tuple(trie) and is_binary(prefix) and byte_size(prefix) <= 20 do
    trie
    |> Radix.more(format_name_for_search(prefix))
    |> Enum.take(25)
    |> Enum.map(fn {_key, {id, display_name}} ->
      value =
        case id_type do
          :string -> to_string(id)
          :integer -> id
        end

      %{
        name: display_name,
        value: value
      }
    end)
    |> Enum.sort_by(&String.downcase(&1.name))
  end

  def wrap_cache_function(cache_module, false) do
    fn key ->
      case Octocon.Accounts.get_user({:discord, key}) do
        nil ->
          {:ignore, nil}

        user ->
          cache_module.cache_function(user)
      end
    end
  end

  def wrap_cache_function(cache_module, true) do
    fn key ->
      {discord_id, supplementary_key} = key

      case Octocon.Accounts.get_user({:discord, discord_id}) do
        nil ->
          {:ignore, nil}

        user ->
          cache_module.cache_function(user, supplementary_key)
      end
    end
  end

  def format_name_for_search(name) do
    name
    |> String.trim()
    |> String.downcase()
  end

  def dispatch(%{user: %{id: discord_id}, data: %{name: command, options: options}} = interaction) do
    focused_option =
      Enum.find(flatten_leaf_options(options), fn opt -> Map.get(opt, :focused, false) end)

    command =
      if command == "friend" do
        case options do
          [%{name: "request"} | _] -> "request"
          _ -> command
        end
      else
        command
      end

    @manager_associations[command].handle_interaction(
      to_string(discord_id),
      focused_option,
      interaction
    )
  rescue
    e ->
      Logger.error("Error handling autocomplete interaction: #{inspect(e)}")
      []
  end

  def invalidate_all(system_identity) do
    discord_id = Octocon.Accounts.id_from_system_identity(system_identity, :discord)

    if discord_id != nil do
      Map.values(@manager_associations)
      |> Enum.each(fn manager -> manager.invalidate(system_identity) end)
    end

    :ok
  end

  defp flatten_leaf_options(options) do
    Enum.flat_map(options, fn
      %{options: nil} = option ->
        [option]

      %{options: children} ->
        flatten_leaf_options(children)
    end)
  end
end
