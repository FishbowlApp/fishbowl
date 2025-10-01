defmodule Octocon.Fronts do
  @moduledoc """
  The Fronts context.
  """

  import Ecto.Query, warn: false

  alias OctoconWeb.System.FrontingJSON

  alias Octocon.{
    Accounts,
    Repo
  }

  alias Octocon.Accounts
  alias Octocon.Alters
  alias Octocon.Alters.Alter
  alias Octocon.Friendships

  alias Octocon.Fronts.{
    CurrentFront,
    Front
  }

  def get_by_id(system_identity, id) do
    system_id = Accounts.id_from_system_identity(system_identity, :system)

    front =
      from(
        f in Front,
        where: f.id == ^id and f.user_id == ^system_id,
        select: f
      )
      |> Repo.one_regional({:user, system_identity})

    if front == nil do
      nil
    else
      alter =
        from(
          a in Alter,
          where: a.id == ^front.alter_id and a.user_id == ^system_id,
          select: struct(a, [:id, :name, :avatar_url, :pronouns, :color, :security_level])
        )
        |> Repo.one_regional({:user, system_identity})

      %{
        front: front,
        alter: alter,
        primary: Accounts.get_primary_front({:system, system_id}) == id
      }
    end
  end

  def delete_front_internal(system_identity, id) do
    system_id = Accounts.id_from_system_identity(system_identity, :system)

    result = Repo.delete_regional(%Front{id: id, user_id: system_id}, {:user, system_identity})

    if match?({:ok, _}, result) do
      spawn(fn ->
        OctoconWeb.Endpoint.broadcast!("system:#{system_id}", "front_deleted", %{
          front_id: id
        })
      end)
    end

    result
  end

  def delete_front(system_identity, id) do
    Octocon.ClusterUtils.run_on_primary(__MODULE__, :delete_front_internal, [system_identity, id])
  end

  def currently_fronting(system_identity) do
    system_id = Accounts.id_from_system_identity(system_identity, :system)
    primary_front = Accounts.get_primary_front({:system, system_id})

    fronts =
      from(
        f in CurrentFront,
        where: f.user_id == ^system_id
      )
      |> Repo.all_regional({:user, system_identity})
      |> Enum.sort_by(& &1.time_start, {:desc, DateTime})
      |> Enum.map(&CurrentFront.to_front/1)

    alters =
      from(
        a in Alter,
        where: a.user_id == ^system_id and a.id in ^Enum.map(fronts, & &1.alter_id),
        select:
          struct(a, [:id, :name, :avatar_url, :pronouns, :color, :security_level, :description])
      )
      |> Repo.all_regional({:user, system_identity})
      |> Enum.into(%{}, fn alter -> {alter.id, alter} end)

    fronts
    |> Enum.map(fn front ->
      alter = Map.get(alters, front.alter_id, %{})
      %{front: front, alter: alter}
    end)
    |> sort_fronts(primary_front)
  end

  def currently_fronting_ids(system_identity) do
    system_id = Accounts.id_from_system_identity(system_identity, :system)

    from(
      f in CurrentFront,
      where: f.user_id == ^system_id,
      select: f.alter_id
    )
    |> Repo.all_regional({:user, system_identity})
  end

  def currently_fronting_guarded(system_identity, caller_identity) do
    friendship_level = Friendships.get_friendship_level(system_identity, caller_identity)

    system_id = Accounts.id_from_system_identity(system_identity, :system)

    primary_front = Accounts.get_primary_front({:system, system_id})

    currently_fronting({:system, system_id})
    |> Enum.filter(fn %{alter: %{security_level: security_level}} ->
      Alters.can_view_entity?(friendship_level, security_level)
    end)
    |> sort_fronts(primary_front)
  end

  def currently_fronting_hoisted(system_identity, friendship_level, currently_fronting) do
    primary_front = Accounts.get_primary_front(system_identity)

    currently_fronting
    |> Enum.filter(fn %{alter: %{security_level: security_level}} ->
      Alters.can_view_entity?(friendship_level, security_level)
    end)
    |> sort_fronts(primary_front)
  end

  defp sort_fronts(fronts, primary_front) do
    if primary_front == nil do
      fronts
      |> Enum.map(fn front -> Map.put(front, :primary, false) end)
    else
      fronts
      |> Enum.map(fn
        %{front: front, alter: alter} ->
          %{front: front, alter: alter, primary: alter.id == primary_front}
      end)
      |> Enum.sort(fn
        %{primary: true, front: %{time_start: a_time_start}},
        %{primary: true, front: %{time_start: b_time_start}} ->
          a_time_start > b_time_start

        %{primary: true, front: %{time_start: _}} = _,
        %{primary: false, front: %{time_start: _}} = _ ->
          true

        %{primary: false, front: %{time_start: _}} = _,
        %{primary: true, front: %{time_start: _}} = _ ->
          false

        %{primary: false, front: %{time_start: a_time_start}},
        %{primary: false, front: %{time_start: b_time_start}} ->
          a_time_start > b_time_start
      end)
    end
  end

  def is_fronting?(system_identity, alter_identity) do
    system_id = Accounts.id_from_system_identity(system_identity, :system)
    alter_id = Alters.resolve_alter({:system, system_id}, alter_identity)

    from(
      f in CurrentFront,
      where: f.user_id == ^system_id and f.alter_id == ^alter_id,
      select: f
    )
    |> Repo.exists?()
  end

  def fronted_between(system_identity, time_start, time_end) do
    system_id = Accounts.id_from_system_identity(system_identity, :system)

    from(
      f in Front,
      where:
        f.user_id == ^system_id and not is_nil(f.time_end) and
          ((f.time_start >= ^time_start and f.time_start <= ^time_end) or
             (f.time_end >= ^time_start and f.time_end <= ^time_end) or
             (f.time_start <= ^time_start and f.time_end >= ^time_end)),
      select: f
    )
    |> Repo.all_regional({:user, system_identity})
    |> Enum.sort_by(& &1.time_start, {:desc, DateTime})
  end

  def fronted_for_month(system_identity, end_anchor \\ DateTime.utc_now()) do
    system_id = Accounts.id_from_system_identity(system_identity, :system)

    from(
      f in Front,
      where:
        f.user_id == ^system_id and
          not is_nil(f.time_end) and
          ((f.time_start >= datetime_add(^end_anchor, -1, "month") and
              f.time_start <= ^end_anchor) or
             (f.time_end >= datetime_add(^end_anchor, -1, "month") and
                f.time_end <= ^end_anchor)),
      select: f
    )
    |> Repo.all_regional({:user, system_identity})
    |> Enum.sort_by(& &1.time_start, {:desc, DateTime})
  end

  def longest_current_fronter(system_identity) do
    system_id = Accounts.id_from_system_identity(system_identity, :system)

    currently_fronting = currently_fronting(system_identity)

    if currently_fronting == [] do
      nil
    else
      currently_fronting
      |> Enum.max_by(fn %{front: front} -> front.time_start end)
      |> Map.put(:primary, Accounts.get_primary_front({:system, system_id}) == front.alter_id)
    end
  end

  def end_front_internal(system_identity, alter_identity) do
    system_id = Accounts.id_from_system_identity(system_identity, :system)
    alter_id = Alters.resolve_alter({:system, system_id}, alter_identity)

    front =
      from(
        f in CurrentFront,
        where: f.user_id == ^system_id and f.alter_id == ^alter_id,
        select: f
      )
      |> Repo.one_regional({:user, system_identity})
      |> CurrentFront.to_front()

    case front do
      nil ->
        {:error, :not_fronting}

      _ ->
        result =
          Repo.update_all_regional(
            from(
              f in Front,
              where: f.user_id == ^system_id and f.alter_id == ^alter_id and f.id == ^front.id
            ),
            [set: [time_end: DateTime.utc_now(:second)]],
            {:user, system_identity}
          )

        case result do
          {1, _} ->
            Repo.delete_all_regional(
              from(
                f in CurrentFront,
                where: f.user_id == ^system_id and f.alter_id == ^alter_id
              ),
              {:user, system_identity}
            )

            if Accounts.get_primary_front({:system, system_id}) == alter_id do
              Accounts.set_primary_front({:system, system_id}, nil)
            end

            spawn(fn ->
              OctoconWeb.Endpoint.broadcast!("system:#{system_id}", "fronting_ended", %{
                alter_id: alter_id
              })
            end)

            spawn(fn ->
              Octocon.ClusterUtils.run_on_primary_no_endpoint(fn ->
                Octocon.Global.FrontNotifier.remove(system_id, alter_id)
              end)
            end)

            :ok

          {0, _} ->
            {:error, :not_set}

          _ ->
            {:error, :unknown}
        end
    end
  end

  def end_front(system_identity, alter_identity) do
    Octocon.ClusterUtils.run_on_primary(__MODULE__, :end_front_internal, [
      system_identity,
      alter_identity
    ])
  end

  def start_front_internal(system_identity, alter_identity, comment \\ "") do
    system_id = Accounts.id_from_system_identity(system_identity, :system)
    alter_id = Alters.resolve_alter({:system, system_id}, alter_identity)

    cond do
      alter_id == false ->
        {:error, :no_alter}

      is_fronting?({:system, system_id}, {:id, alter_id}) ->
        {:error, :already_fronting}

      true ->
        id = Ecto.UUID.generate()

        insertion =
          %Front{
            id: id,
            user_id: system_id,
            alter_id: alter_id,
            comment: comment,
            time_start: DateTime.utc_now(:second)
          }
          |> Repo.insert_regional({:user, system_identity})

        %CurrentFront{
          id: id,
          user_id: system_id,
          alter_id: alter_id,
          comment: comment,
          time_start: DateTime.utc_now(:second)
        }
        |> Repo.insert_regional({:user, system_identity})

        spawn(fn ->
          OctoconWeb.Endpoint.broadcast!("system:#{system_id}", "fronting_started", %{
            front: get_by_id({:system, system_id}, id) |> FrontingJSON.data_me()
          })
        end)

        Octocon.ClusterUtils.run_on_primary_no_endpoint(fn ->
          Octocon.Global.FrontNotifier.add(system_id, alter_id)
        end)

        insertion
    end
  end

  def start_front(system_identity, alter_identity, comment \\ "") do
    Octocon.ClusterUtils.run_on_primary(__MODULE__, :start_front_internal, [
      system_identity,
      alter_identity,
      comment
    ])
  end

  def update_comment_internal(system_identity, front_id, comment) do
    system_id = Accounts.id_from_system_identity(system_identity, :system)

    case get_by_id({:system, system_id}, front_id) do
      nil ->
        {:error, :no_front}

      front ->
        case change_front(front.front, %{comment: comment}) do
          %Ecto.Changeset{valid?: true} = changeset ->
            Repo.update(changeset)

            spawn(fn ->
              OctoconWeb.Endpoint.broadcast!("system:#{system_id}", "front_updated", %{
                front: get_by_id({:system, system_id}, front_id) |> FrontingJSON.data_me()
              })
            end)

            :ok

          %Ecto.Changeset{} = _changeset ->
            {:error, :changeset}
        end
    end
  end

  def update_comment(system_identity, front_id, comment) do
    Octocon.ClusterUtils.run_on_primary(__MODULE__, :update_comment_internal, [
      system_identity,
      front_id,
      comment
    ])
  end

  def bulk_update_fronts_internal(system_identity, start_fronts, end_fronts)
      when is_list(start_fronts) and is_list(end_fronts) do
    system_id = Accounts.id_from_system_identity(system_identity, :system)

    now = DateTime.utc_now(:second)

    if start_fronts != [] do
      Repo.insert_all_regional(
        Front,
        Enum.map(start_fronts, fn %{"id" => alter_id} = data ->
          %{
            id: Ecto.UUID.generate(),
            user_id: system_id,
            alter_id: alter_id,
            comment: data["comment"] || "",
            time_start: now
          }
        end)
      )
    end

    if end_fronts != [] do
      current_front_ids =
        from(
          f in CurrentFront,
          where: f.user_id == ^system_id and f.alter_id in ^end_fronts,
          select: f.id
        )
        |> Repo.all()

      Repo.update_all_regional(
        from(f in Front,
          where: f.user_id == ^system_id and id in ^current_front_ids
        ),
        [set: [time_end: now]],
        {:user, system_identity}
      )

      Repo.delete_all_regional(
        from(f in CurrentFront,
          where: f.user_id == ^system_id and f.alter_id in ^end_fronts
        ),
        {:user, system_identity}
      )

      if Accounts.get_primary_front({:system, system_id}) in end_fronts do
        Accounts.set_primary_front({:system, system_id}, nil)
      end
    end
  end

  def bulk_update_fronts(system_identity, start_fronts, end_fronts) do
    Octocon.ClusterUtils.run_on_primary(__MODULE__, :bulk_update_fronts_internal, [
      system_identity,
      start_fronts,
      end_fronts
    ])
  end

  def set_front_internal(system_identity, alter_identity, comment \\ "") do
    # Sets an alter to front and ends all existing fronts

    system_id = Accounts.id_from_system_identity(system_identity, :system)
    alter_id = Alters.resolve_alter({:system, system_id}, alter_identity)

    cond do
      alter_id == false ->
        {:error, :no_alter}

      is_fronting?({:system, system_id}, {:id, alter_id}) ->
        {:error, :already_fronting}

      true ->
        id = Ecto.UUID.generate()
        now = DateTime.utc_now(:second)

        current_front_ids =
          from(
            f in CurrentFront,
            where: f.user_id == ^system_id,
            select: f.id
          )
          |> Repo.all_regional({:user, system_identity})

        Repo.delete_all_regional(
          from(f in CurrentFront,
            where: f.user_id == ^system_id
          ),
          {:user, system_identity}
        )

        Repo.update_all_regional(
          from(f in Front,
            where: f.user_id == ^system_id and f.id in ^current_front_ids
          ),
          [set: [time_end: now]],
          {:user, system_identity}
        )

        %Front{
          id: id,
          user_id: system_id,
          alter_id: alter_id,
          comment: comment,
          time_start: now,
          time_end: nil
        }
        |> Repo.insert_regional({:user, system_identity})

        %CurrentFront{
          id: id,
          user_id: system_id,
          alter_id: alter_id,
          comment: comment,
          time_start: now
        }
        |> Repo.insert_regional({:user, system_identity})

        Accounts.set_primary_front({:system, system_id}, nil)

        spawn(fn ->
          OctoconWeb.Endpoint.broadcast!("system:#{system_id}", "fronting_set", %{
            front: get_by_id({:system, system_id}, id) |> FrontingJSON.data_me()
          })
        end)

        Octocon.ClusterUtils.run_on_primary_no_endpoint(fn ->
          Octocon.Global.FrontNotifier.set(system_id, alter_id)
        end)

        transaction
    end
  end

  def set_front(system_identity, alter_identity, comment \\ "") do
    Octocon.ClusterUtils.run_on_primary(__MODULE__, :set_front_internal, [
      system_identity,
      alter_identity,
      comment
    ])
  end

  def delete_alter_fronts(system_identity, alter_id) do
    system_id = Accounts.id_from_system_identity(system_identity, :system)

    front_ids =
      from(
        f in FrontByAlter,
        where: f.user_id == ^system_id and f.alter_id == ^alter_id,
        select: f.id
      )
      |> Repo.all()

    from(
      f in Front,
      where: f.user_id == ^system_id and f.id in ^front_ids
    )
    |> Repo.delete_all_regional({:user, system_identity})
  end

  def change_front(%Front{} = front, attrs) do
    Front.changeset(front, attrs)
  end
end
