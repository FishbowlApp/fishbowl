defmodule Octocon.Polls.Poll do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false

  schema "polls" do
    field :id, Ecto.UUID, primary_key: true
    field :user_id, :string

    field :title, :string
    field :description, :string
    field :type, Ecto.Enum, values: [vote: 0, choice: 1], default: :vote
    field :data, :map

    field :time_end, :utc_datetime

    belongs_to :user, Octocon.Accounts.User,
      foreign_key: :user_id,
      define_field: false

    timestamps()
  end

  @doc false
  def changeset(poll, attrs) do
    poll
    |> cast(attrs, [:user_id, :title, :description, :type, :data, :time_end])
    |> validate_length(:title, max: 100)
    |> validate_length(:description, max: 2000)
    |> validate_required([:title, :type, :data])
  end
end
