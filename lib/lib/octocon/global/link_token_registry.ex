defmodule Octocon.Global.LinkTokenRegistry do
  @moduledoc false

  use GenServer
  require Logger

  @inverse_table __MODULE__.Inverse

  @via {:via, Horde.Registry, {Octocon.Primary.HordeRegistry, __MODULE__}}

  # def child_spec(opts) do
  #   name = Keyword.get(opts, :name, __MODULE__)

  #   %{
  #     id: "#{__MODULE__}_#{name}",
  #     start: {__MODULE__, :start_link, [name]}
  #   }
  # end

  def start_link([]) do
    case GenServer.start_link(__MODULE__, [], name: @via) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Logger.info(
          "Global.LinkTokenRegistry already started at #{inspect(pid)}, returning :ignore"
        )

        :ignore
    end
  end

  def put(system_id) do
    GenServer.call(@via, {:put, system_id})
  end

  def get(link_token) do
    GenServer.call(@via, {:get, link_token})
  end

  def delete(link_token) do
    GenServer.call(@via, {:delete, link_token})
  end

  @impl GenServer
  def init([]) do
    :ets.new(__MODULE__, [
      :named_table,
      :set,
      :private
    ])

    :ets.new(@inverse_table, [
      :named_table,
      :set,
      :private
    ])

    {:ok, %{}}
  end

  @impl GenServer
  def handle_call({:put, system_id}, _, state) do
    link_token = Ecto.UUID.generate()

    case :ets.lookup(@inverse_table, system_id) do
      [] ->
        # No existing link token for this system_id
        :ok

      [{_, existing_link_token}] ->
        # Already exists, overwrite
        Logger.info("Overwriting existing link token: #{existing_link_token} with: #{link_token}")
        :ets.delete(__MODULE__, existing_link_token)
        :ets.delete(@inverse_table, system_id)
    end

    :ets.insert(__MODULE__, {link_token, system_id})
    :ets.insert(@inverse_table, {system_id, link_token})

    Process.send_after(self(), {:flush, link_token, system_id}, :timer.minutes(5))

    {:reply, link_token, state}
  end

  @impl GenServer
  def handle_call({:get, link_token}, _, state) do
    case :ets.lookup(__MODULE__, link_token) do
      [] ->
        {:reply, nil, state}

      [{_, system_id}] ->
        {:reply, system_id, state}
    end
  end

  @impl GenServer
  def handle_call({:delete, link_token}, _, state) do
    case :ets.lookup(__MODULE__, link_token) do
      [] ->
        :ok

      [{_, system_id}] ->
        :ets.delete(__MODULE__, link_token)
        :ets.delete(@inverse_table, system_id)
    end

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_info({:flush, link_token, system_id}, state) do
    Logger.debug("Flushing link token: #{link_token}")

    :ets.delete(__MODULE__, link_token)
    :ets.delete(@inverse_table, system_id)

    {:noreply, state}
  end
end
