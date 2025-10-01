defmodule Octocon.Accounts.UserRegistry do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_registry" do
    field :user_id, :string, primary_key: true
    field :discord_id, :string
    field :email, :string
    field :username, :string
    field :apple_id, :string
    field :google_id, :string

    field :region, :string

    timestamps()
  end

  def update_changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [
      :user_id,
      :discord_id,
      :email,
      :username,
      :apple_id,
      :google_id,
      :region
    ])
  end
end
