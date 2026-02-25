defmodule OctoconDiscord.StatusUpdater do
  @moduledoc """
  Manages a subset of shards for the Octocon Discord bot.
  """

  use GenServer

  require Logger

  @via {:via, Horde.Registry, {Octocon.Primary.HordeRegistry, __MODULE__}}

  @interval :timer.minutes(5)

  def start_link([]) do
    case GenServer.start_link(__MODULE__, [], name: @via) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Logger.info(
          "OctoconDiscord.StatusUpdater already started at #{inspect(pid)}, returning :ignore"
        )

        :ignore
    end
  end

  def start do
    GenServer.call(@via, :start)
  end

  def bump({this_shard, shard_count}) do
    GenServer.cast(@via, {:bump, {this_shard, shard_count}})
  end

  @impl GenServer
  def init([]) do
    {:ok, {:stopped, 0}}
  end

  @impl GenServer
  def handle_cast({:bump, {this_shard, shard_count}}, {:stopped, bump_count}) do
    Logger.info("Received bump from shard #{this_shard}/#{shard_count}.")

    new_count = bump_count + 1

    if new_count >= shard_count do
      Logger.info("All shards have bumped; starting OctoconDiscord.StatusUpdater.")

      update_status()
      Process.send_after(self(), :update, @interval)

      {:noreply, :started}
    else
      {:noreply, {:stopped, new_count}}
    end
  end

  @impl GenServer
  def handle_info(:update, state) do
    update_status()
    Process.send_after(self(), :update, @interval)

    {:noreply, state}
  end

  defp update_status do
    Logger.info("Updating Discord status...")

    guild_count = :mnesia.table_info(Nostrum.Cache.GuildCache.Mnesia.table(), :size)

    Nostrum.Api.Self.update_status(
      :online,
      {:custom, "/help | In #{format_number(guild_count)} servers!"}
    )
  end

  # E.g. 12345678 to "12,345,678"
  def format_number(num) do
    num
    |> :erlang.integer_to_list()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
    |> Enum.join(",")
  end
end
