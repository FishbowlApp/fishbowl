defmodule OctoconWeb.PollController do
  use OctoconWeb, :controller

  alias Octocon.Polls

  def index(conn, _params) do
    system_id = conn.private[:guardian_default_resource]

    Polls.get_polls({:system, system_id})
    |> then(fn polls -> render(conn, :index, polls: polls) end)
  end

  def show(conn, %{"id" => poll_id}) do
    system_id = conn.private[:guardian_default_resource]

    case Polls.get_poll({:system, system_id}, poll_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Poll not found.", code: "poll_not_found"})

      entry ->
        conn
        |> render(:show, entry: entry)
    end
  end

  def create(conn, attrs) do
    system_id = conn.private[:guardian_default_resource]

    attrs =
      Map.take(attrs, [
        "title",
        "description",
        "type",
        "time_end"
      ])
      |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end)
      |> Map.new()

    case Polls.create_poll({:system, system_id}, attrs) do
      {:error, :not_found} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "An unknown error occurred.", code: "unknown_error"})

      {:error, :changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "Invalid poll attributes.",
          code: "invalid_poll_attributes"
        })

      {:ok, entry} ->
        conn
        |> put_status(:created)
        |> render(:show, entry: entry)
    end
  end

  def delete(conn, %{"id" => poll_id}) do
    system_id = conn.private[:guardian_default_resource]

    case Polls.delete_poll({:system, system_id}, poll_id) do
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Poll not found.", code: "poll_not_found"})

      :ok ->
        conn
        |> put_status(:no_content)
        |> send_resp(:no_content, "")
    end
  end

  def update(conn, %{"id" => poll_id} = attrs) do
    system_id = conn.private[:guardian_default_resource]

    attrs =
      Map.take(attrs, [
        "title",
        "description",
        "time_end",
        "data"
      ])
      |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end)
      |> Map.new()

    if map_size(attrs) == 0 do
      conn
      |> put_status(:bad_request)
      |> json(%{
        error: "No valid poll attributes provided.",
        code: "no_poll_attributes"
      })
    else
      case Polls.update_poll({:system, system_id}, poll_id, attrs) do
        {:ok, _entry} ->
          send_resp(conn, :no_content, "")

        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "Poll not found.", code: "poll_not_found"})

        {:error, :changeset} ->
          conn
          |> put_status(:bad_request)
          |> json(%{
            error: "Invalid poll attributes.",
            code: "invalid_poll_attributes"
          })

        _ ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "An unknown error occurred.", code: "unknown_error"})
      end
    end
  end
end
