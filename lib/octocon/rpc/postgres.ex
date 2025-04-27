defmodule Octocon.RPC.Postgres do
  @moduledoc false
  require Logger

  @type env :: :prod | :dev | :test

  def local_repo(opts \\ []) do
    Octocon.RPC.Postgres.LSN.Tracker.get_repo(opts)
  end

  @doc """
  Execute the MFA (Module, Function, Arguments) on a node in the primary group.
  This waits for the data to be replicated to the current node before continuing
  on.

  This presumes the primary group has direct access to a writable primary
  Postgres database.

  ## Options

  - `:tracker` - The name of the tracker to wait on for replication tracking.
  - `:rpc_timeout` - Timeout duration to wait for RPC call to complete
  - `:replication_timeout` - Timeout duration to wait for replication to complete.
  """
  def rpc_and_wait(module, func, args, opts \\ []) do
    rpc_timeout = Keyword.get(opts, :rpc_timeout, 5_000)

    {lsn_value, result} =
      Octocon.RPC.NodeTracker.rpc_group(
        :primary,
        {__MODULE__, :__rpc_lsn__, [module, func, args, opts]},
        timeout: rpc_timeout
      )

    case Octocon.RPC.Postgres.LSN.Tracker.request_and_await_notification(lsn_value, opts) do
      :ready ->

        result

      {:error, :timeout} ->
        exit(:timeout)
    end
  end

  @doc false
  # Private function executed on the primary
  @spec __rpc_lsn__(module(), func :: atom(), args :: [any()], opts :: Keyword.t()) ::
          {:wal_lookup_failure | Octocon.RPC.Postgres.LSN.t(), any()}
  def __rpc_lsn__(module, func, args, opts) do
    # Execute the MFA in the primary group
    result = apply(module, func, args)

    # Use `local_repo` here to read most recent WAL value from DB that the
    # caller needs to wait for replication to complete in order to continue and
    # have access to the data.
    # lsn_value = Octocon.RPC.Postgres.LSN.current_wal_insert(Octocon.RPC.Postgres.local_repo(opts))
    lsn_value =
      try do
        Octocon.RPC.Postgres.LSN.current_wal_insert(Octocon.RPC.Postgres.local_repo(opts))
      rescue
        _ in Postgrex.Error ->
          :wal_lookup_failure
      end

    {lsn_value, result}
  end
end
