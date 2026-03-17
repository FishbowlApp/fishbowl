defmodule OctoconDiscord.Cache.ChannelBlacklists do
  @doc """
  Manages the channel blacklist.

  [TODO]: Rework this to use the database instead of holding everything in ETS if memory pressure becomes an issue.
  """
  alias Octocon.ChannelBlacklists
  alias Octocon.ChannelBlacklists.ChannelBlacklist
  use GenServer
  require Logger

  # Client

  @doc false
  def start_link(_init_arg) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Adds a channel to the blacklist.
  """
  def add(guild_id, channel_id) when is_binary(guild_id) and is_binary(channel_id) do
    if :ets.lookup(__MODULE__, channel_id) != [] do
      {:error, :already_blacklisted}
    else
      :ets.insert(__MODULE__, {channel_id, []})

      ChannelBlacklists.create_channel_blacklist(%{guild_id: guild_id, channel_id: channel_id})

      :ok
    end
  end

  @doc """
  Removes a channel from the blacklist.
  """
  def remove(channel_id) when is_binary(channel_id) do
    if :ets.lookup(__MODULE__, channel_id) == [] do
      {:error, :not_blacklisted}
    else
      :ets.delete(__MODULE__, channel_id)
      ChannelBlacklists.delete_channel_blacklist(%ChannelBlacklist{channel_id: channel_id})

      :ok
    end
  end

  @doc """
  Checks if a channel is blacklisted.
  """
  def blacklisted?(channel_id, parent_id)

  def blacklisted?(channel_id, nil) when is_binary(channel_id) do
    :ets.lookup(__MODULE__, channel_id) != []
  end

  def blacklisted?(channel_id, parent_id)
      when is_binary(channel_id) and is_binary(parent_id) do
    :ets.lookup(__MODULE__, channel_id) != [] or :ets.lookup(__MODULE__, parent_id) != []
  end

  @doc """
  Gets all blacklisted channels for a guild.
  """
  def get_all_for_guild(guild_id) when is_binary(guild_id) do
    ChannelBlacklists.list_channel_blacklists_by_guild(guild_id)
  end

  # Server

  @doc false
  @impl GenServer
  def init([]) do
    :ets.new(__MODULE__, [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true,
      decentralized_counters: true
    ])

    {:ok, [], {:continue, :load_blacklists}}
  end

  @impl GenServer
  def handle_continue(:load_blacklists, state) do
    # [TODO]: Replace this with actual waiting
    Process.sleep(:timer.seconds(5))

    channels = ChannelBlacklists.list_channel_blacklists_bare()

    :ets.insert(
      __MODULE__,
      channels
      |> Enum.map(fn channel_id -> {channel_id, []} end)
    )

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(_, state) do
    {:noreply, state}
  end
end
