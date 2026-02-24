defmodule OctoconDiscord.Components do
  @moduledoc false

  use Supervisor

  @dispatchers %{
    "alter" => __MODULE__.AlterHandler,
    "alter-pag" => __MODULE__.AlterPaginator,
    "tag" => __MODULE__.TagHandler,
    "tag-pag" => __MODULE__.TagPaginator,
    "wipe-alters" => __MODULE__.WipeAltersHandler,
    "wipe-tags" => __MODULE__.WipeTagsHandler,
    "delete-account" => __MODULE__.DeleteAccountHandler,
    "help" => __MODULE__.HelpHandler,
    "reproxy" => __MODULE__.ReproxyHandler
  }

  @dispatcher_servers [
    __MODULE__.AlterPaginator,
    __MODULE__.TagPaginator,
    __MODULE__.WipeAltersHandler,
    __MODULE__.WipeTagsHandler,
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

    uid =
      case Integer.parse(uid) do
        {int, ""} -> int
        {_int, _rest} -> uid
        :error -> uid
      end

    Map.get(@dispatchers, type).handle_interaction(action, uid, interaction)
  end
end
