defmodule Octocon.Accounts.ServerSettings do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :guild_id, :string

    field :proxying_disabled, :boolean, default: false

    field :autoproxy_mode, Ecto.Enum, values: [off: 0, front: 1, latch: 2], default: :off
    field :latched_alter, :integer, default: nil
  end

  def changeset(data, attrs \\ %{}) do
    data
    |> cast(attrs, [:guild_id, :proxying_disabled, :autoproxy_mode, :latched_alter])
    |> validate_required([:guild_id])
  end
end
