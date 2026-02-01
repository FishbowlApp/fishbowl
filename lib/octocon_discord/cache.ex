defmodule OctoconDiscord.Cache do
  use Supervisor

  @caches [
    __MODULE__.ChannelBlacklists,
    __MODULE__.Proxy,
    __MODULE__.ServerSettings,
    __MODULE__.Webhooks
  ]

  def start_link(_), do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  def init([]) do
    Supervisor.init(@caches, strategy: :one_for_one)
  end
end
