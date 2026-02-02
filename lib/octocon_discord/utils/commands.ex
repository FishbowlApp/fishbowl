defmodule OctoconDiscord.Utils.Commands do
  import OctoconDiscord.Utils.Components

  alias Octocon.Accounts

  def get_command_option(options, name) do
    case Enum.find(options, fn %{name: option} -> option == name end) do
      nil -> nil
      option -> Map.get(option, :value)
    end
  end

  def register_message,
    do:
      error_component(
        "You're not registered. Use the `/register` command or link your Discord account to your existing system."
      )

  def ensure_registered(discord_id, callback) do
    if Accounts.user_exists?({:discord, discord_id}) do
      callback.()
    else
      register_message()
    end
  end

  def add_show_option(options) do
    options ++
      [
        %{
          name: "show",
          description: "Show this message to the entire channel instead of just you.",
          type: :boolean,
          required: false
        }
      ]
  end

  def get_show_option(options) do
    case get_command_option(options, "show") do
      nil -> false
      value -> value
    end
  end

  def system_id_from_opts(opts, callback) do
    num_opts = Enum.count(Map.keys(opts))
    num_nil = Map.values(opts) |> Enum.count(&is_nil/1)

    cond do
      num_nil == num_opts ->
        error_component("You must specify a system ID, Discord ping, or username.")

      num_nil != num_opts - 1 ->
        error_component("You must *only* specify a system ID, Discord ping, *or* username.")

      opts.system_id ->
        if Accounts.user_exists?({:system, opts.system_id}) do
          callback.({:system, opts.system_id}, "**#{opts.system_id}**")
        else
          error_component("A system does not exist with ID **#{opts.system_id}**.")
        end

      opts.discord_id ->
        discord_id = to_string(opts.discord_id)

        if Accounts.user_exists?({:discord, discord_id}) do
          callback.({:discord, discord_id}, "<@#{discord_id}>")
        else
          error_component("A system does not exist with that Discord account.")
        end

      opts.username ->
        case Accounts.get_user_id_by_username(opts.username) do
          nil ->
            error_component("A system does not exist with username **#{opts.username}**.")

          system_id ->
            callback.({:system, system_id}, "**#{opts.username}**")
        end

      true ->
        error_component("An unknown error occurred.")
    end
  end
end
