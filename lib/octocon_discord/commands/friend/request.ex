defmodule OctoconDiscord.Commands.Friend.Request do
  @moduledoc false

  alias Octocon.Friendships
  alias OctoconDiscord.Utils

  @subcommands %{
    "send" => &__MODULE__.send/2,
    "accept" => &__MODULE__.accept/2,
    "reject" => &__MODULE__.reject/2,
    "cancel" => &__MODULE__.cancel/2,
    "list" => &__MODULE__.list/2
  }

  def command(context, options) do
    subcommand = hd(options)

    @subcommands[subcommand.name].(
      context,
      subcommand.options
    )
  end

  def send(context, options) do
    opts = %{
      system_id: Utils.get_command_option(options, "system-id"),
      discord_id: Utils.get_command_option(options, "discord"),
      username: Utils.get_command_option(options, "username")
    }

    Utils.system_id_from_opts(opts, fn identity, decorator ->
      send_friend_request(context, identity, decorator)
    end)
  end

  def accept(context, options) do
    opts = %{
      system_id: Utils.get_command_option(options, "system-id"),
      discord_id: Utils.get_command_option(options, "discord")
    }

    Utils.system_id_from_opts(opts, fn identity, decorator ->
      accept_friend_request(context, identity, decorator)
    end)
  end

  def reject(context, options) do
    opts = %{
      system_id: Utils.get_command_option(options, "system-id"),
      discord_id: Utils.get_command_option(options, "discord")
    }

    Utils.system_id_from_opts(opts, fn identity, decorator ->
      reject_friend_request(context, identity, decorator)
    end)
  end

  def cancel(context, options) do
    opts = %{
      system_id: Utils.get_command_option(options, "system-id"),
      discord_id: Utils.get_command_option(options, "discord")
    }

    Utils.system_id_from_opts(opts, fn identity, decorator ->
      cancel_friend_request(context, identity, decorator)
    end)
  end

  def list(%{system_identity: system_identity}, _options) do
    incoming_requests = Friendships.incoming_friend_requests(system_identity)
    outgoing_requests = Friendships.outgoing_friend_requests(system_identity)

    if incoming_requests == [] and outgoing_requests == [] do
      Utils.error_component(
        "You don't have any incoming or outgoing friend requests. Add a friend with `/friend add`!"
      )
    else
      incoming_component =
        if incoming_requests != [] do
          [
            Utils.container(
              [
                Utils.text("## Incoming friend requests (#{length(incoming_requests)})"),
                Utils.separator(spacing: :large),
                Enum.map(incoming_requests, fn
                  %{
                    request: %{from_id: from_id},
                    from: %{username: username, discord_id: discord_id}
                  } ->
                    Utils.text(
                      "- **#{username || from_id}**#{case discord_id do
                        nil -> ""
                        _ -> " (<@#{discord_id}>)"
                      end}"
                    )
                end)
              ]
              |> List.flatten()
            )
          ]
        else
          []
        end

      outgoing_component =
        if outgoing_requests != [] do
          [
            Utils.container(
              [
                Utils.text("## Outgoing friend requests (#{length(outgoing_requests)})"),
                Utils.separator(spacing: :large),
                Enum.map(outgoing_requests, fn
                  %{
                    request: %{to_id: to_id},
                    to: %{username: username, discord_id: discord_id}
                  } ->
                    Utils.text(
                      "- **#{username || to_id}**#{case discord_id do
                        nil -> ""
                        _ -> " (<@#{discord_id}>)"
                      end}"
                    )
                end)
              ]
              |> List.flatten()
            )
          ]
        else
          []
        end

      [
        components: incoming_component ++ outgoing_component,
        flags: Utils.cv2_flags()
      ]
    end
  end

  defp send_friend_request(%{system_identity: system_identity}, to_identity, decorator) do
    case Friendships.send_request(system_identity, to_identity) do
      {:ok, :sent} ->
        Utils.success_component("Sent a friend request to #{decorator}.")

      {:ok, :accepted} ->
        Utils.success_component(
          "You are now friends with #{decorator}!\n\nIf you'd like to add them as a trusted friend, use `/friend trust`."
        )

      {:error, :already_friends} ->
        Utils.error_component("You are already friends with #{decorator}.")

      {:error, :already_sent_request} ->
        Utils.error_component("You have already sent a friend request to #{decorator}.")

      {:error, %{errors: [to_id: {"does not exist", _}]}} ->
        Utils.error_component("That system #{decorator} does not exist.")

      {:error, _} ->
        Utils.error_component(
          "An unknown error occurred while sending the friend request. Please try again."
        )
    end
  end

  defp accept_friend_request(%{system_identity: system_identity}, from_identity, decorator) do
    case Friendships.accept_request(from_identity, system_identity) do
      :ok ->
        Utils.success_component(
          "You are now friends with #{decorator}!\n\nIf you'd like to add them as a trusted friend, use `/friend trust`."
        )

      {:error, :not_requested} ->
        Utils.error_component("You do not have an incoming friend request from #{decorator}.")

      {:error, :no_user} ->
        Utils.error_component("The system #{decorator} does not exist.")

      {:error, _} ->
        Utils.error_component(
          "An unknown error occurred while accepting the friend request. Please try again."
        )
    end
  end

  defp reject_friend_request(%{system_identity: system_identity}, from_identity, decorator) do
    case Friendships.reject_request(from_identity, system_identity) do
      :ok ->
        Utils.success_component("You rejected the friend request from #{decorator}.")

      {:error, :not_requested} ->
        Utils.error_component("You do not have an incoming friend request from #{decorator}.")

      {:error, :no_user} ->
        Utils.error_component("The system #{decorator} does not exist.")

      {:error, _} ->
        Utils.error_component(
          "An unknown error occurred while rejecting the friend request. Please try again."
        )
    end
  end

  defp cancel_friend_request(%{system_identity: system_identity}, to_identity, decorator) do
    case Friendships.cancel_request(system_identity, to_identity) do
      :ok ->
        Utils.success_component("You canceled the friend request to #{decorator}.")

      {:error, :not_requested} ->
        Utils.error_component("You do not have an outgoing friend request to #{decorator}.")

      {:error, :no_user} ->
        Utils.error_component("The system #{decorator} does not exist.")

      {:error, _} ->
        Utils.error_component(
          "An unknown error occurred while cancelling the friend request. Please try again."
        )
    end
  end
end
