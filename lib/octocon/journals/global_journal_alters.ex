defmodule Octocon.Journals.GlobalJournalAlters do
  @moduledoc """
  A join table entry associating an alter with a global journal entry.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "global_journal_alters" do
    field :user_id, :string, primary_key: true
    field :global_journal_id, Ecto.UUID, primary_key: true
    field :alter_id, :integer, primary_key: true

    # belongs_to :global_journal, Octocon.Journals.GlobalJournalEntry,
    #  foreign_key: :global_journal_id,
    #  define_field: false

    # belongs_to :alter, Octocon.Alters.Alter,
    #  foreign_key: :alter_id,
    #  define_field: false
  end

  @doc """
  Builds a changeset based on the given `Octocon.Journals.GlobalJournalAlters` struct and `attrs` to change.
  """
  def changeset(global_journal_entry, attrs \\ %{}) do
    global_journal_entry
    |> cast(attrs, [:global_journal_id, :alter_id])
    |> foreign_key_constraint(:global_journal_id)
    |> foreign_key_constraint(:alter_id)
    |> unique_constraint([:global_journal_id, :alter_id])
    |> validate_required([:user_id, :global_journal_id, :alter_id])
  end
end
