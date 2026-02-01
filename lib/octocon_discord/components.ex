defmodule OctoconDiscord.Components do
  @moduledoc false

  use Supervisor

  @dispatchers %{
    "alter" => __MODULE__.AlterHandler,
    "alter-pag" => __MODULE__.AlterPaginator,
    "wipe-alters" => __MODULE__.WipeAltersHandler,
    "delete-account" => __MODULE__.DeleteAccountHandler,
    "help" => __MODULE__.HelpHandler,
    "reproxy" => __MODULE__.ReproxyHandler
  }

  @dispatcher_servers [
    __MODULE__.AlterPaginator,
    __MODULE__.WipeAltersHandler,
    __MODULE__.DeleteAccountHandler,
    __MODULE__.HelpHandler,
    __MODULE__.ReproxyHandler
  ]

  def start_link(_), do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  def init([]) do
    Supervisor.init(@dispatcher_servers, strategy: :one_for_one)
  end

  def dispatch(interaction) do
    [type, action, uid] = String.split(interaction.data.custom_id, "|")

    Map.get(@dispatchers, type).handle_interaction(action, String.to_integer(uid), interaction)
  end
end
