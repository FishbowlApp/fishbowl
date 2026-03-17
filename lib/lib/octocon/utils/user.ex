defmodule Octocon.Utils.User do
  @moduledoc """
  Utility functions for working with users.
  """

  alias Octocon.{
    Accounts,
    Utils
  }

  alias OctoconWeb.Uploaders.UserAvatar

  @doc """
  Uploads an avatar for the given system to the Octocon CDN.

  ## Arguments

  - `system` (struct): The system to upload the avatar for.
  - `url` (binary): The URL of the avatar to download and re-upload to the Octocon CDN.
  """
  def upload_avatar(system, url) do
    random_id = Nanoid.generate(30)

    avatar_scope = %{
      system_id: system.id,
      random_id: random_id
    }

    Utils.nuke_existing_avatars!(system.id, "self")

    to_store =
      if String.starts_with?(url, "http") do
        url
      else
        # Convert file URL to an actual binary to be sent to the sidecar node.

        %{
          filename: "primary.webp",
          binary: File.read!(url)
        }
      end

    result =
      Octocon.ClusterUtils.run_on_sidecar(fn -> UserAvatar.store({to_store, avatar_scope}) end,
        timeout: 10_000
      )

    case result do
      {:ok, _} ->
        avatar_url = UserAvatar.url({"primary.webp", avatar_scope}, :primary)

        Accounts.update_user(system, %{avatar_url: avatar_url})

      _ ->
        {:error, :unknown}
    end
  end
end
