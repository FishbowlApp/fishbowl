defmodule Octocon.UserRegistryCache do
  @moduledoc false

  def get_region(system_identity) do
    Cachex.fetch!(Octocon.Cache.UserRegistry, system_identity, &Octocon.UserRegistryCache.cache_function/1)
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
