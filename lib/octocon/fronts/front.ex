defmodule Octocon.Fronts.Front do
  @moduledoc """
  A front entry for an alter. This is used to track a single instance of an alter's front status. It consists of:

  - A user ID (7-character alphanumeric lowercase string)
  - An alter ID (integer up to 32,767)
  - A comment (optional, up to 50 characters)
  - A start time (UTC datetime)
  - An end time (UTC datetime, nil if the alter is currently fronting)
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "fronts" do
    field :user_id, :string, primary_key: true
    field :id, Ecto.UUID, primary_key: true
    field :alter_id, :integer
    field :comment, :string, default: ""

    field :time_start, :utc_datetime, primary_key: true
    field :time_end, :utc_datetime

    # belongs_to :user, Octocon.Accounts.User,
    #  type: :string,
    #  foreign_key: :user_id,
    #  define_field: false

    # belongs_to :alter, Octocon.Alters.Alter,
    #  type: :integer,
    #  foreign_key: :alter_id,
    #  define_field: false
  end

  @doc """
  Builds a changeset based on the given `Octocon.Fronts.Front` struct and `attrs` to change.
  """
  def changeset(front, attrs) do
    front
    |> cast(attrs, [:user_id, :alter_id, :comment])
    |> validate_required([:user_id, :alter_id])
    |> validate_length(:comment, max: 50)
  end

  @doc """
  Builds a changeset to create a new front entry based on the given `user_id`, `alter_id`, and extra `attrs`.
  """
  def create_changeset(user_id, alter_id, attrs) do
    %__MODULE__{user_id: user_id, alter_id: alter_id, time_start: DateTime.utc_now(:second)}
    |> cast(attrs, [:user_id, :alter_id, :comment, :time_start])
    |> validate_required([:user_id, :alter_id, :time_start])
    |> validate_length(:comment, max: 50)
  end
end

defmodule Octocon.Fronts.CurrentFront do
  @moduledoc false
  use Ecto.Schema

  @primary_key false

  schema "current_fronts" do
    field :id, Ecto.UUID
    field :user_id, :string
    field :alter_id, :integer
    field :comment, :string, default: ""

    field :time_start, :utc_datetime
  end

  def to_front(%__MODULE__{} = current_front) do
    %Octocon.Fronts.Front{
      id: current_front.id,
      user_id: current_front.user_id,
      alter_id: current_front.alter_id,
      comment: current_front.comment,
      time_start: current_front.time_start,
      time_end: nil
    }
  end

  def to_front(nil), do: nil
end

defmodule Octocon.Fronts.FrontByAlter do
  @moduledoc false
  use Ecto.Schema

  @primary_key false

  schema "fronts_by_alter" do
    field :id, Ecto.UUID
    field :user_id, :string
    field :alter_id, :integer
    field :comment, :string, default: ""

    field :time_start, :utc_datetime
    field :time_end, :utc_datetime
  end

  def to_front(%__MODULE__{} = front) do
    %Octocon.Fronts.Front{
      id: front.id,
      user_id: front.user_id,
      alter_id: front.alter_id,
      comment: front.comment,
      time_start: front.time_start,
      time_end: front.time_end
    }
  end

  def to_front(nil), do: nil
end

defmodule Octocon.Fronts.FrontByTime do
  @moduledoc false
  use Ecto.Schema

  @primary_key false

  schema "fronts_by_time" do
    field :id, Ecto.UUID
    field :user_id, :string
    field :alter_id, :integer
    field :comment, :string, default: ""

    field :time_start, :utc_datetime
    field :time_end, :utc_datetime
  end

  def to_front(%__MODULE__{} = front) do
    %Octocon.Fronts.Front{
      id: front.id,
      user_id: front.user_id,
      alter_id: front.alter_id,
      comment: front.comment,
      time_start: front.time_start,
      time_end: front.time_end
    }
  end

  def to_front(nil), do: nil
end

defmodule Octocon.Fronts.FrontByEndTime do
  @moduledoc false
  use Ecto.Schema

  @primary_key false

  schema "fronts_by_end_time" do
    field :id, Ecto.UUID
    field :user_id, :string
    field :alter_id, :integer
    field :comment, :string, default: ""

    field :time_start, :utc_datetime
    field :time_end, :utc_datetime
  end

  def to_front(%__MODULE__{} = front) do
    %Octocon.Fronts.Front{
      id: front.id,
      user_id: front.user_id,
      alter_id: front.alter_id,
      comment: front.comment,
      time_start: front.time_start,
      time_end: front.time_end
    }
  end

  def to_front(nil), do: nil
end
