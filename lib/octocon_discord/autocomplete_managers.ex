defmodule OctoconDiscord.AutocompleteManagers do
  @moduledoc false

  use Supervisor

  @manager_associations %{
    "alter" => OctoconDiscord.AutocompleteManagers.Alter
  }

  def start_link(_), do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  def init([]) do
    children = [
      OctoconDiscord.AutocompleteManagers.Alter
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defmacro __using__(_opts) do
    quote do
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
          when is_binary(discord_id) and is_binary(prefix) and byte_size(prefix) <= 20 do
        Task.async(fn -> do_fetch(discord_id, prefix) end)
        |> Task.await(@timeout)
      end

      defp do_fetch(discord_id, prefix) do
        trie =
          Cachex.fetch!(
            __MODULE__,
            discord_id,
            OctoconDiscord.AutocompleteManagers.wrap_cache_function(&__MODULE__.cache_function/1)
          )

        if trie == nil do
          []
        else
          generate_autocomplete_responses(trie, prefix)
        end
      end

      def invalidate({:discord, discord_id}) when is_binary(discord_id) do
        Cachex.del(__MODULE__, discord_id)
      end

      def invalidate(system_identity) do
        case Octocon.Accounts.get_user(system_identity) do
          %{discord_id: discord_id} when discord_id != nil -> invalidate({:discord, discord_id})
          _ -> {:ok, true}
        end
      end
    end
  end

  def generate_autocomplete_responses(trie, prefix, id_type \\ :string)
      when is_tuple(trie) and is_binary(prefix) and byte_size(prefix) <= 20 do
    results =
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
      |> Enum.sort_by(& &1.name)
  end

  def wrap_cache_function(cache_function) when is_function(cache_function, 1) do
    fn discord_id ->
      case Octocon.Accounts.get_user({:discord, discord_id}) do
        nil ->
          {:ignore, nil}

        user ->
          cache_function.(user)
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

  defp flatten_leaf_options(options) do
    Enum.flat_map(options, fn
      %{options: nil} = option ->
        [option]

      %{options: children} ->
        flatten_leaf_options(children)
    end)
  end
end
