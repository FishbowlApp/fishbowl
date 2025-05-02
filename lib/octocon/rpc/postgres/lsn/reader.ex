defmodule Octocon.RPC.Postgres.LSN.Reader do
  @moduledoc """
  Watches the configured database for replication changes.

  When a change is found, it writes it to an ETS cache and notifies registered
  and waiting processes when their update is received.
  """
  use GenServer
  require Logger

  alias Octocon.RPC.Postgres.LSN
  alias Octocon.RPC.Postgres.LSN.Tracker

  ###
  ### CLIENT
  ###

  def start_link(opts \\ []) do
    if !Keyword.has_key?(opts, :repo) do
      raise ArgumentError, ":repo must be given when starting the LSN Reader"
    end

    name = get_name(Keyword.fetch!(opts, :base_name))
    GenServer.start_link(__MODULE__, Keyword.put(opts, :name, name), name: name)
  end

  ###
  ### SERVER CALLBACKS
  ###

  def init(opts) do
    repo = Keyword.fetch!(opts, :repo)
    base_name = Keyword.fetch!(opts, :base_name)
    reader_name = Keyword.fetch!(opts, :name)

    lsn_cache_table = Tracker.get_lsn_cache_table(opts)
    requests_table = Tracker.get_request_tracking_table(opts)

    # if conditions are right, request to start watching for LSN changes
    conditionally_start_watching()

    # Initial state.
    {:ok,
     %{
       name: reader_name,
       base_name: base_name,
       lsn_table: lsn_cache_table,
       requests_table: requests_table,
       repo: repo
     }}
  end

  def handle_info(:watch_for_lsn_change, state) do
    # Read the current LSN from the cache
    last_lsn = Tracker.get_last_replay(base_name: state.base_name)

    # execute stored procedure
    case LSN.last_wal_replay_watch(state.repo, last_lsn) do
      nil ->
        # nothing to do
        :ok

      %LSN{} = new_lsn ->
        # write the update LSN to the cache and process any pending requests
        Tracker.write_lsn_to_cache(new_lsn, state.lsn_table)
        Tracker.process_request_entries(state.base_name)
        :ok
    end

    # trigger self to check again
    send(self(), :watch_for_lsn_change)

    {:noreply, state}
  end

  # Only start the watching process if running in a non-primary region.
  defp conditionally_start_watching() do
    if Octocon.RPC.NodeTracker.is_primary?() do
      Logger.info("Detected running on primary. No local replication to track.")
    else
      # request the watching procedure to start
      send(self(), :watch_for_lsn_change)
    end
  end

  @doc """
  Get the name of the reader instance that is derived from the base tracking
  name.
  """
  # Atom interpolation is OK here because it is provided by dev.
  # sobelow_skip ["DOS.BinToAtom"]
  @spec get_name(atom()) :: atom()
  def get_name(base_name) when is_atom(base_name) do
    :"#{base_name}_reader"
  end
end
