defmodule OctoconDiscord.Supervisor do
  @moduledoc """
  Root supervisor for the Discord portion of the Octocon application. This supervisor is guaranteed to be running on a primary node.
  """
  use Supervisor

  import Cachex.Spec

  alias Octocon.ClusterUtils

  require Logger

  def start_link(_init_arg) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl Supervisor
  def init([]) do
    children = [
      # Cachex-backed cache managers
      OctoconDiscord.ServerSettingsManager,
      OctoconDiscord.WebhookManager,
      OctoconDiscord.AutocompleteManagers.Alter,

      # Custom ETS-backed persistent caches
      OctoconDiscord.ProxyCache,
      OctoconDiscord.ChannelBlacklistManager,

      # Component handlers
      OctoconDiscord.Components.HelpHandler,
      OctoconDiscord.Components.AlterPaginator,
      OctoconDiscord.Components.WipeAltersHandler,
      OctoconDiscord.Components.DeleteAccountHandler,
      OctoconDiscord.Components.ReproxyHandler,
      Nostrum.Application,
      Supervisor.child_spec({Task, fn -> start_status_updater() end}, id: :start_status_updater),

      # Gateway events
      Supervisor.child_spec({Task, fn -> start_unique_consumer() end},
        id: :start_unique_consumer
      ),

      # Application commands
      {Nosedrum.Storage.Dispatcher, name: Nosedrum.Storage.Dispatcher}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp init_shards do
    node_count = ClusterUtils.primary_node_count()
    desired_shards = OctoconDiscord.get_desired_shards()

    for i <- 1..node_count do
      # If desired_shards is 100, and we have 4 nodes, we want to start shards 0-24 on node 1, 25-49 on node 2, etc.
      start_shard = div((i - 1) * desired_shards, node_count)
      end_shard = div(i * desired_shards, node_count) - 1

      Horde.DynamicSupervisor.start_child(
        Octocon.Primary.HordeSupervisor,
        {OctoconDiscord.ShardManager, {i, start_shard, end_shard, desired_shards}}
      )
    end
  end

  def start_unique_consumer do
    Logger.info("Starting unique consumer")

    Horde.DynamicSupervisor.start_child(
      Octocon.Primary.HordeSupervisor,
      OctoconDiscord.ConsumerSupervisor
    )
  end

  defp start_status_updater do
    Logger.info("Starting status updater")

    Horde.DynamicSupervisor.start_child(
      Octocon.Primary.HordeSupervisor,
      OctoconDiscord.StatusUpdater
    )
  end
end
