defmodule OctoconDiscord.AutocompleteManagers.Alter do
  @moduledoc false

  import Cachex.Spec

  use Octocon.CachexChild,
    name: __MODULE__,
    hooks: [
      hook(
        module: Cachex.Limit.Scheduled,
        args: {2000, [], [frequency: :timer.seconds(30)]}
      )
    ],
    expiration: expiration(default: :timer.minutes(5))
end
