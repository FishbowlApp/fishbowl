defmodule Octocon.Accounts.DiscordSettings do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset
  import Exandra, only: [embedded_type: 3]

  @primary_key false
  embedded_schema do
    field :system_tag, :string, default: nil
    field :show_system_tag, :boolean, default: false

    field :case_insensitive_proxies, :boolean, default: false
    field :show_pronouns, :boolean, default: true
    field :ids_as_proxies, :boolean, default: false
    field :silent_proxying, :boolean, default: false
    field :use_proxy_delay, :boolean, default: false

    field :global_autoproxy_mode, Ecto.Enum, values: [off: 0, front: 1, latch: 2], default: :off
    field :global_latched_alter, :integer, default: nil

    embedded_type(:server_settings, Octocon.Accounts.ServerSettings, cardinality: :many)
  end

  def changeset(data, attrs \\ %{}) do
    data
    |> cast(attrs, [
      :system_tag,
      :show_system_tag,
      :case_insensitive_proxies,
      :show_pronouns,
      :ids_as_proxies,
      :silent_proxying,
      :server_settings,
      :use_proxy_delay,
      :global_autoproxy_mode,
      :global_latched_alter
    ])
    |> validate_length(:system_tag, max: 20)
  end

  def server_settings_map(%__MODULE__{server_settings: server_settings}) do
    (server_settings || [])
    |> Enum.map(fn %Octocon.Accounts.ServerSettings{
                     guild_id: guild_id,
                     proxying_disabled: proxying_disabled,
                     autoproxy_mode: autoproxy_mode,
                     latched_alter: latched_alter
                   } ->
      {guild_id,
       %{
         proxying_disabled: proxying_disabled,
         autoproxy_mode: autoproxy_mode,
         latched_alter: latched_alter
       }}
    end)
    |> Enum.into(%{})
  end
end
