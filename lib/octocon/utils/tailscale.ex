defmodule Octocon.Utils.Tailscale do
  @moduledoc false

  @polling_interval 30_000
  @endpoint "api.tailscale.com/api/v2"
  @tailnet "octocondev.org.github"

  def list_devices do
    case get("/tailnet/#{@tailnet}/devices") do
      {:ok, devices} ->
        devices["devices"]

      _ ->
        []
    end
  end

  def get(path) do
    authkey = Application.get_env(:octocon, :tailscale_api_authkey)

    case :httpc.request(:get, {'https://#{authkey}:@#{@endpoint}/#{path}', []}, [], []) do
      {:ok, {{_version, 200, _status}, _headers, body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, {{_version, code, status}, _headers, body}} ->
        {:warn, [code, status, body]}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
