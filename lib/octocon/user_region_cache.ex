defmodule Octocon.UserRegistryCache do
  @moduledoc false

  def get_region(system_identity) do
    Cachex.fetch!(
      Octocon.Cache.UserRegistry,
      system_identity,
      &Octocon.UserRegistryCache.cache_function/1
    )
  end

  def invalidate(system_identity) do
    user = Octocon.Accounts.get_user!(system_identity)

    Cachex.del(Octocon.Cache.UserRegistry, {:system, user.id})

    [
      {:discord, user.discord_id},
      {:apple, user.apple_id},
      {:google, user.google_id},
      {:email, user.email}
    ]
    |> Enum.filter(fn {_, id} -> id != nil end)
    |> Enum.each(fn id -> Cachex.del(Octocon.Cache.UserRegistry, id) end)
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
