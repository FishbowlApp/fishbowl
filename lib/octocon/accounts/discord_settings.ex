defmodule Octocon.Accounts.DiscordSettings do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

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

    embeds_many :server_settings, ServerSettings, primary_key: false, on_replace: :delete do
      field :guild_id, :string

      field :proxying_disabled, :boolean, default: false

      field :autoproxy_mode, Ecto.Enum, values: [off: 0, front: 1, latch: 2], default: :off
      field :latched_alter, :integer, default: nil
    end
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
      :use_proxy_delay,
      :global_autoproxy_mode,
      :global_latched_alter
    ])
    |> validate_length(:system_tag, max: 20)
    |> cast_embed(:server_settings, with: &server_settings_changeset/2)
  end

  def server_settings_changeset(data, attrs \\ %{}) do
    data
    |> cast(attrs, [:guild_id, :proxying_disabled, :autoproxy_mode, :latched_alter])
    |> validate_required([:guild_id])
  end

  def server_settings_map(%__MODULE__{server_settings: server_settings}) do
    server_settings
    |> Enum.map(fn %__MODULE__.ServerSettings{
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
