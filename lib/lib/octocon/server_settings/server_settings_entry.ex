defmodule Octocon.ServerSettings.ServerSettingsEntry do
  @moduledoc """
  A server settings entry for a given Discord guild. It consists of:

  - A Discord guild ID (a 17-22 character numeric string)
  - A data field (an embedded schema containing server settings)

  This data currently includes:
  - A log channel ID (a 17-22 character numeric string)
  - A flag to force system tags on all proxied messages
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Exandra, only: [embedded_type: 2]

  @primary_key false

  schema "server_settings" do
    field :guild_id, :string, primary_key: true
    embedded_type(:data, Octocon.ServerSettings.ServerSettingsData)

    timestamps()
  end

  @doc """
  Builds a changeset based on the given `Octocon.ServerSettings.ServerSettingsEntry` struct and `attrs` to change.
  """
  def changeset(%__MODULE__{} = server_settings_entry, attrs \\ %{}) do
    server_settings_entry
    |> cast(attrs, [:guild_id, :data])
    |> validate_required([:guild_id])
  end
end
