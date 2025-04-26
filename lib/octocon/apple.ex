defmodule Octocon.Apple do
  @expiration_sec 86400 * 180

  defp generate_secret do
    secret =
      UeberauthApple.generate_client_secret(%{
        client_id: Application.fetch_env!(:octocon, :apple_client_id),
        expires_in: @expiration_sec,
        key_id: Application.fetch_env!(:octocon, :apple_private_key_id),
        team_id: Application.fetch_env!(:octocon, :apple_team_id),
        private_key: Application.fetch_env!(:octocon, :apple_private_key)
      })

    :persistent_term.put(__MODULE__, {secret, System.os_time(:second) + @expiration_sec})
  end

  def get_client_secret(_config \\ []) do
    case :persistent_term.get(__MODULE__, nil) do
      nil ->
        generate_secret()

      {secret, exp_time} ->
        if exp_time < System.os_time(:second) do
          generate_secret()
        else
          secret
        end
    end
  end
end
