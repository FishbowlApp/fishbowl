defmodule OctoconWeb.AuthController do
  use OctoconWeb, :controller

  alias Octocon.Accounts
  alias Octocon.Accounts.User
  alias Octocon.Auth.Guardian
  alias Octocon.Repo

  plug :put_metadata
  plug Ueberauth

  @request_paths [
    "/auth/discord",
    "/auth/google"
  ]

  def put_metadata(
        %{
          params: %{
            "platform" => platform,
            "version_code" => version_code,
            "is_beta" => is_beta
          }
        } = conn,
        _params
      ) do
    if conn.request_path in @request_paths do
      metadata =
        Jason.encode!(%{
          "platform" => to_string(platform),
          "version_code" => to_string(version_code),
          "is_beta" => to_string(is_beta)
        })

      conn
      |> put_session(:metadata, metadata)
    else
      conn
    end
  end

  def put_metadata(conn, _params) do
    if conn.request_path in @request_paths do
      conn
      |> put_session(
        :metadata,
        Jason.encode!(%{
          "platform" => "unknown",
          "version_code" => "unknown",
          "is_beta" => "false"
        })
      )
    else
      conn
    end
  end

  def request(conn, _params) do
    conn
    |> send_resp(403, "")
  end

  def callback(%{assigns: %{ueberauth_auth: %{uid: discord_id}}} = conn, %{
        "provider" => "discord"
      }) do
    user =
      case Repo.get_by(User, discord_id: discord_id) do
        nil -> Accounts.create_user_from_discord(discord_id) |> elem(1)
        user -> user
      end

    {:ok, token, _claims} = Guardian.encode_and_sign(user.id)

    metadata = get_session(conn, :metadata) |> Jason.decode!()

    url_params = "?token=#{token}&id=#{user.id}"

    redirect_url =
      case metadata do
        %{"platform" => "wasm", "is_beta" => "true"} -> "https://beta.octocon.app/app"
        %{"platform" => "wasm", "is_beta" => "false"} -> "https://octocon.app/app"
        _ -> "https://octocon.app/deep/auth/token"
      end
      |> Kernel.<>(url_params)

    redirect(conn, external: redirect_url)
  end

  def callback(%{assigns: %{ueberauth_auth: %{info: %{email: email}}}} = conn, %{
        "provider" => "google"
      }) do
    user =
      case Repo.get_by(User, email: email) do
        nil -> Accounts.create_user_from_email(email) |> elem(1)
        user -> user
      end

    {:ok, token, _claims} = Guardian.encode_and_sign(user.id)

    metadata = get_session(conn, :metadata) |> Jason.decode!()

    url_params = "?token=#{token}&id=#{user.id}"

    redirect_url =
      case metadata do
        %{"platform" => "wasm", "is_beta" => "true"} -> "https://beta.octocon.app/app"
        %{"platform" => "wasm", "is_beta" => "false"} -> "https://octocon.app/app"
        _ -> "https://octocon.app/deep/auth/token"
      end
      |> Kernel.<>(url_params)

    redirect(conn, external: redirect_url)
  end

  def callback(%{assigns: %{ueberauth_auth: %{uid: apple_id}}} = conn, %{
        "provider" => "apple"
      }) do
    user =
      case Repo.get_by(User, apple_id: apple_id) do
        nil -> Accounts.create_user_from_apple(apple_id) |> elem(1)
        user -> user
      end

    {:ok, token, _claims} = Guardian.encode_and_sign(user.id)

    url_params = "?token=#{token}&id=#{user.id}"

    redirect(conn, external: "https://octocon.app/deep/auth/token#{url_params}")
  end

  def callback(conn, params) do
    IO.inspect("START CONN")
    IO.inspect(conn, limit: :infinity)
    IO.inspect("END CONN")
    IO.inspect("START PARAMS")
    IO.inspect(params, limit: :infinity)
    IO.inspect("END PARAMS")

    conn
    |> put_status(403)
    |> text("Failed to authenticate. Did you reload the page or copy-paste the URL?")
  end
end
