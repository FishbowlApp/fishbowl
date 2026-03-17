defmodule Octocon.Journals.GlobalJournalEntry do
  @moduledoc """
  A journal entry that is "global" (i.e. not tied to a specific alter). It consists of:

  - A user ID (7-character alphanumeric lowercase string)
  - A title (up to 100 characters)
  - Content (up to 20,000 characters)
  - A color (optional, a hexadecimal color code, e.g. `#ff0000`)
  - A list of alter IDs that are associated with this journal entry (virtual, populated by the data layer)
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "global_journals" do
    field :user_id, :string, primary_key: true
    field :id, Ecto.UUID, primary_key: true

    field :title, :string
    field :content, :string
    field :color, :string
    field :pinned, :boolean, default: false
    field :locked, :boolean, default: false

    field :alters, {:array, :integer}, virtual: true

    timestamps()
  end

  @doc """
  Builds a changeset based on the given `Octocon.Journals.GlobalJournalEntry` struct and `attrs` to change.
  """
  def changeset(global_journal_entry, attrs) do
    global_journal_entry
    |> cast(attrs, [:title, :content, :color, :pinned, :locked])
    |> validate_length(:title, max: 100)
    |> validate_length(:content, max: 50_000)
    |> validate_format(:color, ~r/^#[0-9a-fA-F]{6}$/)
    |> validate_required([:title])
  end
end
