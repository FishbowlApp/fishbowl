defmodule Octocon.Accounts.User do
  @moduledoc """
  A user represents a single Octocon account. It consists of:

  - An ID (7-character alphanumeric lowercase string)
  - An email address (optional)
  - A Discord ID (optional)
  - A username (optional)
  - An avatar URL (optional)
  - A lifetime alter count (integer, used to generate new alter IDs without conflicts)
  - A primary front (integer ID of the primary fronting alter or nil)
  - An autoproxy mode (enum, one of `:off`, `:front`, or `:latch`)
  - A system tag (optional, a short string to identify the system, used on Discord)
  - A flag to show the system tag on Discord (boolean)
  - A flag to enable case-insensitive proxying (boolean)
  - A flag to show pronouns on proxied messages (boolean)

  A user MUST have either an email address, a Discord ID, or both, but not neither.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Exandra, only: [embedded_type: 3]

  @primary_key false

  schema "users" do
    field :id, :string, primary_key: true
    field :region, :string, virtual: true

    field :discord_id, :string
    field :apple_id, :string
    field :google_id, :string
    field :email, :string

    field :username, :string

    field :avatar_url, :string
    field :description, :string

    field :lifetime_alter_count, :integer, default: 0
    field :primary_front, :integer

    embedded_type(:discord_settings, Octocon.Accounts.DiscordSettings, cardinality: :one)
    embedded_type(:fields, Octocon.Accounts.Field, cardinality: :many)

    field :salt, :string
    field :encryption_initialized, :boolean, default: false
    field :encryption_key_checksum, :string

    timestamps()
  end

  defp global_validations(changeset) do
    changeset
    |> validate_format(:id, ~r/^[a-z]{7}$/)
    |> validate_format(:email, ~r/@/)
    |> validate_format(:discord_id, ~r/^\d{17,22}$/)
    |> validate_length(:description, max: 3000)
    # Dear christ help me
    |> validate_format(:username, ~r/^[a-zA-Z0-9]([a-zA-Z0-9_\-.]{3,22})[a-zA-Z0-9]$/)
    # Make username not able to look like a system id (primary key)
    |> validate_format(:username, ~r/^(?:(?![a-z]{7}).*)$/)
    |> validate_inclusion(:primary_front, 1..32_767)
    |> unique_constraint(:email)
    |> unique_constraint(:discord_id)
    |> unique_constraint(:apple_id)
    |> unique_constraint(:google_id)
    |> unique_constraint(:username)
  end

  @doc """
  Builds a changeset based on the given `Octocon.Accounts.User` struct and `attrs` to change.
  """
  def update_changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [
      :id,
      :email,
      :discord_id,
      :apple_id,
      :avatar_url,
      :username,
      :lifetime_alter_count,
      :primary_front,
      :description,
      :discord_settings,
      :fields,
      :salt,
      :encryption_initialized,
      :encryption_key_checksum
    ])
    |> global_validations()
  end

  @doc """
  Builds a changeset to create a new user with the given `discord_id` and extra `attrs`.
  """
  def create_from_discord_changeset(discord_id, uuid, attrs) do
    %__MODULE__{
      discord_id: to_string(discord_id),
      id: uuid,
      salt: generate_salt()
    }
    |> cast(attrs, [:id, :email, :discord_id, :username])
    |> validate_required([:id, :discord_id])
    |> global_validations()
  end

  @doc """
  Builds a changeset to create a new user with the given `apple_id` and extra `attrs`.
  """
  def create_from_apple_changeset(apple_id, uuid, attrs) do
    %__MODULE__{
      apple_id: to_string(apple_id),
      id: uuid,
      salt: generate_salt()
    }
    |> cast(attrs, [:id, :email, :apple_id, :username])
    |> validate_required([:id, :apple_id])
    |> global_validations()
  end

  @doc """
  Builds a changeset to create a new user with the given `email` and extra `attrs`.
  """
  def create_from_email_changeset(email, uuid, attrs) do
    %__MODULE__{
      email: email,
      id: uuid,
      salt: generate_salt()
    }
    |> cast(attrs, [:id, :email, :discord_id, :username])
    |> validate_required([:id, :email])
    |> global_validations()
  end

  def generate_uuid do
    id = Nanoid.generate(7, "abcdefghijklmnopqrstuvwxyz")
  end

  defp generate_salt do
    :crypto.strong_rand_bytes(32) |> Base.encode64()
  end
end
