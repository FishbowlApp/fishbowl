defmodule OctoconDiscord.WebhookManager do
  @moduledoc false

  import Cachex.Spec

  use Octocon.CachexChild,
    name: __MODULE__,
    hooks: [
      hook(module: Cachex.Limit.Scheduled, args: {5000, [], [frequency: :timer.seconds(30)]})
    ],
    expiration: expiration(default: :timer.minutes(10))

  alias Nostrum.Api

  @proxy_name "Octocon Proxy"
  @timeout :timer.seconds(5)

  def get_webhook(channel_id) do
    Task.async(fn -> do_fetch(channel_id) end)
    |> Task.await(@timeout)
  end

  defp do_fetch(channel_id) do
    case Cachex.fetch!(
           __MODULE__,
           channel_id,
           &cache_function/1
         ) do
      %{id: _, token: _} = result -> result
      _ -> nil
    end
  end

  def cache_function(channel_id) do
    case Api.Channel.webhooks(channel_id) do
      {:ok, webhooks} ->
        case Enum.find(webhooks, fn webhook -> webhook.name == @proxy_name end) do
          webhook when is_map(webhook) ->
            {:commit, %{id: webhook.id, token: webhook.token}}

          nil ->
            {:ok, webhook} = Api.Webhook.create(channel_id, %{name: @proxy_name})
            {:commit, %{id: webhook.id, token: webhook.token}}
        end

      _ ->
        {:ignore, nil}
    end
  end
end
