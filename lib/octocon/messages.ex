defmodule Octocon.Messages do
  @moduledoc """
  The Messages context.
  """

  import Ecto.Query, warn: false
  alias Octocon.MessageRepo, as: Repo

  alias Octocon.Messages.Message

  def insert_message(attrs) do
    Octocon.RPC.NodeTracker.rpc_primary(fn ->
      %Message{}
      |> Message.changeset(attrs)
      |> Repo.insert()
    end)
  end

  def lookup_message(message_id) do
    Octocon.RPC.NodeTracker.rpc_primary(fn ->
      message_timestamp = Nostrum.Snowflake.creation_time(message_id)

      query =
        from m in Message,
          where: m.message_id == ^to_string(message_id),
          where: m.timestamp == ^message_timestamp,
          limit: 1

      Repo.one(query)
    end)
  end
end
