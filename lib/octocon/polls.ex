defmodule Octocon.Polls do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Octocon.{
    Accounts,
    Repo
  }

  alias Octocon.Polls.Poll
  alias OctoconWeb.PollJSON

  defp unwrap_system_identity_where(system_identity, extra \\ []) do
    case system_identity do
      {:system, system_id} ->
        [user_id: system_id] |> Keyword.merge(extra)

      {:discord, _} = identity ->
        [user_id: Accounts.id_from_system_identity(identity, :system)]
        |> Keyword.merge(extra)
    end
  end

  def get_polls(system_identity) do
    where = unwrap_system_identity_where(system_identity)

    query =
      Poll
      |> where(^where)
      |> select([p], p)

    Repo.all(query)
  end

  def get_poll(system_identity, poll_id) do
    where = unwrap_system_identity_where(system_identity, id: poll_id)

    query =
      Poll
      |> where(^where)
      |> select([p], p)

    Repo.one(query)
  end

  def create_poll(system_identity, attrs) do
    case Accounts.id_from_system_identity(system_identity, :system) do
      nil ->
        {:error, :not_found}

      system_id ->
        id = Ecto.UUID.generate()

        result =
          %Poll{
            id: id,
            user_id: system_id,
            data: %{}
          }
          |> change_poll(attrs)
          |> Repo.insert()

        case result do
          {:ok, poll} ->
            spawn(fn ->
              OctoconWeb.Endpoint.broadcast!(
                "system:#{system_id}",
                "poll_created",
                %{
                  poll: PollJSON.data(poll)
                }
              )
            end)

            {:ok, poll}

          _ ->
            {:error, :changeset}
        end
    end
  end

  def delete_poll(system_identity, poll_id) do
    system_id = Accounts.id_from_system_identity(system_identity, :system)
    where = unwrap_system_identity_where({:system, system_id}, id: poll_id)

    query =
      Poll
      |> where(^where)

    case Repo.delete_all(query) do
      {1, _} ->
        spawn(fn ->
          OctoconWeb.Endpoint.broadcast!(
            "system:#{system_id}",
            "poll_deleted",
            %{poll_id: poll_id}
          )
        end)

        :ok

      _ ->
        {:error, :not_found}
    end
  end

  def update_poll_internal(system_identity, poll_id, attrs) do
    case get_poll(system_identity, poll_id) do
      nil ->
        {:error, :not_found}

      poll ->
        result =
          poll
          |> change_poll(attrs)
          |> Repo.update()

        case result do
          {:ok, poll} ->
            spawn(fn ->
              OctoconWeb.Endpoint.broadcast!(
                "system:#{poll.user_id}",
                "poll_updated",
                %{
                  poll: PollJSON.data(poll)
                }
              )
            end)

            {:ok, poll}

          _ ->
            {:error, :changeset}
        end
    end
  end

  def update_poll(system_identity, poll_id, attrs) do
    Fly.Postgres.rpc_and_wait(__MODULE__, :update_poll_internal, [system_identity, poll_id, attrs])
  end

  @doc """
  Builds a changeset based on the given `Octocon.Polls.Poll` struct and `attrs` to change.
  """
  def change_poll(%Poll{} = poll, attrs \\ %{}) do
    Poll.changeset(poll, attrs)
  end
end
