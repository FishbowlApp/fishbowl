defmodule OctoconDiscord.BotSupervisor do
  use Supervisor

  require Logger

  @via {:via, Horde.Registry, {Octocon.Primary.HordeRegistry, __MODULE__}}

  def start_link(_init_arg) do
    case Supervisor.start_link(__MODULE__, [], name: @via) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Logger.warning(
          "OctoconDiscord.BotSupervisor already started at #{inspect(pid)}, returning :ignore"
        )

        :ignore
    end
  end

  def init([]) do
    bot_options = %{
      name: OctoconDiscord.Bot,
      consumer: OctoconDiscord.Consumer,
      intents: [
        :guild_webhooks,
        :guilds,
        :guild_messages,
        :guild_message_reactions,
        :direct_messages,
        :direct_message_reactions,
        :message_content
      ],
      wrapped_token: fn -> Application.get_env(:octocon, :discord_token) end
    }

    children = [
      {Nostrum.Bot, bot_options}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def get_bot_pid do
    case Horde.Registry.lookup(Octocon.Primary.HordeRegistry, __MODULE__) do
      [] ->
        :error

      [{pid, _}] ->
        [{_, bot_pid, _, _}] = Supervisor.which_children(pid)
        {:ok, bot_pid}
    end
  end
end
