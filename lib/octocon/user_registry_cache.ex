defmodule Octocon.UserRegistryCache do
  @moduledoc false

  import Cachex.Spec

  use Octocon.CachexChild,
    name: __MODULE__,
    hooks: [
      hook(
        module: Cachex.Limit.Scheduled,
        args: {20_000, [], [frequency: :timer.seconds(30)]}
      )
    ]

  def get_region(system_identity) do
    Cachex.fetch!(
      __MODULE__,
      system_identity,
      &cache_function/1
    )
  end

  def invalidate(system_identity) do
    user = Octocon.Accounts.get_user!(system_identity)

    Cachex.del(__MODULE__, {:system, user.id})

    [
      {:discord, user.discord_id},
      {:apple, user.apple_id},
      {:google, user.google_id},
      {:email, user.email}
    ]
    |> Enum.filter(fn {_, id} -> id != nil end)
    |> Enum.each(fn id -> Cachex.del(__MODULE__, id) end)
  end

  def cache_function(system_identity) do
    region = Octocon.Accounts.region_for_user(system_identity)

    if region == nil do
      {:ignore, nil}
    else
      {:commit, region}
    end
  end
end
