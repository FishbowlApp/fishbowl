defmodule Octocon.NotificationTokens.NotificationToken do
  @moduledoc """
  A token used to send mobile push notifications to a user. It consists of:

  - A user ID (7-character alphanumeric lowercase string)
  - A push token (a unique string identifying the device to be sent to Firebase Cloud Messaging)
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "notification_tokens" do
    field :user_id, :string, primary_key: true
    field :push_token, :string, primary_key: true

    timestamps()
  end

  @doc """
  Builds a changeset based on the given `Octocon.NotificationTokens.NotificationToken` struct and `attrs` to change.
  """
  def changeset(notification_token, attrs) do
    notification_token
    |> cast(attrs, [:user_id, :push_token])
    |> validate_required([:user_id, :push_token])
  end
end
