defmodule Octocon.ClusterUtils do
  @moduledoc """
  Utility functions for working with the currently running node cluster.
  """

  alias Octocon.RPC.NodeTracker

  @doc """
  Check if the current node is a primary node.
  """
  def is_primary?, do: NodeTracker.is_primary?()
  def is_primary_no_endpoint?, do: NodeTracker.is_primary_no_endpoint?()

  @doc """
  Get a list of all primary nodes in the cluster.

  If `include_self` is `true`, the current node will be included in the list if it is a primary node. Otherwise, the current node will be excluded.
  """
  def primary_nodes(include_self \\ false)

  def primary_nodes(false) do
    NodeTracker.primary_nodes()
  end

  def primary_nodes(true) do
    other_nodes = primary_nodes(false)

    if is_primary?() do
      [Node.self() | other_nodes]
    else
      other_nodes
    end
  end

  def primary_no_endpoint_nodes(include_self \\ false)

  def primary_no_endpoint_nodes(false) do
    NodeTracker.primary_no_endpoint_nodes()
  end

  def primary_no_endpoint_nodes(true) do
    other_nodes = primary_no_endpoint_nodes(false)

    if is_primary_no_endpoint?() do
      [Node.self() | other_nodes]
    else
      other_nodes
    end
  end

  def primary_nodes_incl_no_endpoint(include_self \\ false)

  def primary_nodes_incl_no_endpoint(false) do
    NodeTracker.primary_nodes() ++ NodeTracker.primary_no_endpoint_nodes()
  end

  def primary_nodes_incl_no_endpoint(true) do
    other_nodes = primary_nodes(false) ++ primary_nodes_incl_no_endpoint(false)

    if is_primary?() or is_primary_no_endpoint?() do
      [Node.self() | other_nodes]
    else
      other_nodes
    end
  end

  @doc """
  Run the given function on all primary nodes in the cluster. If the current node is a primary node, the function will be run locally as well
  without any RPC overhead.
  """
  def run_on_all_primary_nodes(fun) do
    # If we are a primary node, run the function locally as well
    if NodeTracker.is_primary?() do
      fun.()
    end

    primary_nodes()
    |> Task.async_stream(fn node ->
      NodeTracker.rpc(node, fun)
    end)
    |> Enum.map(fn
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end)
  end

  def run_on_all_primary_no_endpoint_nodes(fun) do
    # If we are a primary node, run the function locally as well
    if NodeTracker.is_primary_no_endpoint?() do
      fun.()
    end

    primary_no_endpoint_nodes()
    |> Task.async_stream(fn node ->
      NodeTracker.rpc(node, fun)
    end)
    |> Enum.map(fn
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end)
  end

  def run_on_sidecar(fun, opts \\ []) do
    NodeTracker.rpc_group(:sidecar, fun, opts)
  end

  def run_on_primary(fun, opts \\ []) do
    NodeTracker.rpc_group(:primary, fun, opts)
  end

  def run_on_primary(m, f, a) do
    NodeTracker.rpc_group(:primary, {m, f, a})
  end

  def run_on_primary_no_endpoint(fun, opts \\ []) do
    NodeTracker.rpc_group(:primary_no_endpoint, fun, opts)
  end

  @doc """
  Get the number of desired functional (non-standby) primary nodes in the cluster.
  """
  def primary_node_count do
    Application.get_env(:octocon, :primary_node_count, 1)
  end

  def check_primary(node) do
    Octocon.RPC.NodeTracker.rpc(node, fn ->
      NodeTracker.is_primary?()
    end)
  end
end
