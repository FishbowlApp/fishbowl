defmodule Octocon.RPC.Postgres.LSN do
    alias __MODULE__
  
    defstruct fpart: nil, offset: nil, source: nil
  
    @type t :: %LSN{
            fpart: nil | integer,
            offset: nil | integer,
            source: :not_replicating | :insert | :replay
          }
  
    @spec new(lsn :: nil | String.t(), source :: :insert | :replay) :: no_return() | t()
    def new(nil, :replay) do
      %LSN{fpart: nil, offset: nil, source: :not_replicating}
    end
  
    def new(lsn, source) when is_binary(lsn) and source in [:insert, :replay] do
      with [file_part_str, offset_str] <- String.split(lsn, "/"),
           {fpart, ""} = Integer.parse(file_part_str, 16),
           {offset, ""} = Integer.parse(offset_str, 16) do
        %LSN{fpart: fpart, offset: offset, source: source}
      else
        _ -> raise ArgumentError, "invalid lsn format #{inspect(lsn)}"
      end
    end
  
    def replicated?(replay_lsn, insert_lsn)
    def replicated?(%LSN{source: :not_replicating}, %LSN{source: :insert}), do: true
  
    def replicated?(%LSN{fpart: f1, offset: o1, source: :replay}, %LSN{
          fpart: f2,
          offset: o2,
          source: :insert
        }) do
      f1 > f2 or (f1 == f2 and o1 >= o2)
    end
  
    @spec to_text(t()) :: nil | String.t()
    def to_text(%LSN{fpart: nil, offset: nil}), do: nil
  
    def to_text(%LSN{fpart: fpart, offset: offset}) do
      Integer.to_string(fpart, 16) <> "/" <> Integer.to_string(offset, 16)
    end
  
    def current_wal_insert(repo) do
      %Postgrex.Result{rows: [[lsn]]} =
        repo.query!("select CAST(pg_current_wal_insert_lsn() AS TEXT)")
  
      new(lsn, :insert)
    end
  
    def last_wal_replay(repo) do
      %Postgrex.Result{rows: [[lsn]]} = repo.query!("select CAST(pg_last_wal_replay_lsn() AS TEXT)")
      new(lsn, :replay)
    end
  
    @spec last_wal_replay_watch(module(), nil | t()) :: nil | t()
    def last_wal_replay_watch(repo, from_lsn) do
      param_value =
        case from_lsn do
          nil -> nil
          %LSN{} -> to_text(from_lsn)
        end
  
      %Postgrex.Result{rows: [[result]]} =
        repo.query!("SELECT watch_for_lsn_change($1, 2);", [param_value])
  
      case result do
        nil -> nil
        lsn_text -> new(lsn_text, :replay)
      end
    end
  end
  
  defimpl Inspect, for: Octocon.RPC.Postgres.LSN do
    import Inspect.Algebra
  
    def inspect(lsn, _opts) do
      concat(["#LSN<", Octocon.RPC.Postgres.LSN.to_text(lsn), ">"])
    end
  end