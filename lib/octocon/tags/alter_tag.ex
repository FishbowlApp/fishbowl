defmodule Octocon.Tags.AlterTag do
  @moduledoc """
  A join table entry associating a tag with an alter.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "alter_tags" do
    field :user_id, :string, primary_key: true
    field :tag_id, Ecto.UUID, primary_key: true
    field :alter_id, :integer, primary_key: true

    timestamps()
  end

  @doc """
  Builds a changeset based on the given `Octocon.Tags.AlterTag` struct and `attrs` to change.
  """
  def changeset(alter_tag, attrs \\ %{}) do
    alter_tag
    |> cast(attrs, [:tag_id, :alter_id])
    |> foreign_key_constraint(:tag_id)
    |> foreign_key_constraint(:alter_id)
    |> unique_constraint([:tag_id, :alter_id])
    |> validate_required([:user_id, :tag_id, :alter_id])
  end
end
