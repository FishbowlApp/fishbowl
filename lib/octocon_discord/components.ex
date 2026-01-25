defmodule OctoconDiscord.Components do
  @moduledoc false

  @dispatchers %{
    "alter" => __MODULE__.AlterHandler,
    "alter-pag" => __MODULE__.AlterPaginator,
    "wipe-alters" => __MODULE__.WipeAltersHandler,
    "delete-account" => __MODULE__.DeleteAccountHandler,
    "help" => __MODULE__.HelpHandler,
    "reproxy" => __MODULE__.ReproxyHandler
  }

  def dispatch(interaction) do
    [type, action, uid] = String.split(interaction.data.custom_id, "|")

    Map.get(@dispatchers, type).handle_interaction(action, String.to_integer(uid), interaction)
  end
end
