defmodule OctoconDiscord.Commands.Friend do
  @moduledoc false

  use OctoconDiscord.Commands

  @behaviour Nosedrum.ApplicationCommand

  require Logger

  alias Octocon.Friendships

  @subcommands %{
    "request" => &__MODULE__.Request.command/2,
    "remove" => &__MODULE__.remove/2,
    "list" => &__MODULE__.list/2,
    "trust" => &__MODULE__.trust/2,
    "untrust" => &__MODULE__.untrust/2
  }

  @impl Nosedrum.ApplicationCommand
  def description, do: "Manages your friends."

  @impl Nosedrum.ApplicationCommand
  def command(interaction) do
    %{data: %{resolved: resolved}, user: %{id: discord_id}} = interaction
    discord_id = to_string(discord_id)

    ensure_registered(discord_id, fn ->
      %{data: %{options: [%{name: name, options: options}]}} = interaction

      @subcommands[name].(
        %{resolved: resolved, system_identity: {:discord, discord_id}},
        options
      )
    end)
  end

  def remove(context, options) do
    opts = %{
      system_id: get_command_option(options, "system-id"),
      discord_id: get_command_option(options, "discord"),
      username: get_command_option(options, "username")
    }

    system_id_from_opts(opts, fn identity, decorator ->
      remove_friend(context, identity, decorator)
    end)
  end

  def list(%{system_identity: system_identity}, _options) do
    case Friendships.list_friendships(system_identity) do
      [] ->
        error_component("You have no friends (yet!). Add some with `/friend add`!")

      friendships ->
        [
          components: [
            container([
              text("## Your friends (#{length(friendships)})"),
              separator(spacing: :large),
              text(
                Enum.map_join(friendships, "\n", fn %{friend: friend, friendship: %{level: level}} ->
                  "- **#{friend.username || friend.id}** (#{case friend.discord_id do
                    nil -> ""
                    id -> "<@#{id}>"
                  end}#{case level do
                    :trusted_friend -> "; :star:"
                    :friend -> ""
                  end})"
                end)
              ),
              separator(spacing: :large),
              text("*⭐ = Trusted friend*")
            ])
          ],
          flags: cv2_flags()
        ]
    end
  end

  def trust(context, options) do
    opts = %{
      system_id: get_command_option(options, "system-id"),
      discord_id: get_command_option(options, "discord"),
      username: get_command_option(options, "username")
    }

    system_id_from_opts(opts, fn identity, decorator ->
      trust_friend(context, identity, decorator)
    end)
  end

  def untrust(context, options) do
    opts = %{
      system_id: get_command_option(options, "system-id"),
      discord_id: get_command_option(options, "discord"),
      username: get_command_option(options, "username")
    }

    system_id_from_opts(opts, fn identity, decorator ->
      untrust_friend(context, identity, decorator)
    end)
  end

  defp trust_friend(%{system_identity: system_identity}, target_identity, decorator) do
    case Friendships.trust_friend(system_identity, target_identity) do
      :ok ->
        success_component("#{decorator} is now a trusted friend!")

      {:error, :not_friends} ->
        error_component("You are not friends with #{decorator}.")

      {:error, _} ->
        error_component("An unknown error occurred while trusting the friend. Please try again.")
    end
  end

  defp untrust_friend(%{system_identity: system_identity}, target_identity, decorator) do
    case Friendships.untrust_friend(system_identity, target_identity) do
      :ok ->
        success_component("#{decorator} is no longer a trusted friend!")

      {:error, :not_friends} ->
        error_component("You are not friends with #{decorator}.")

      {:error, _} ->
        error_component(
          "An unknown error occurred while untrusting the friend. Please try again."
        )
    end
  end

  defp remove_friend(%{system_identity: system_identity}, target_identity, decorator) do
    case Friendships.remove_friendship(system_identity, target_identity) do
      :ok ->
        success_component("You are no longer friends with #{decorator}!")

      {:error, :not_friends} ->
        error_component("You are not friends with #{decorator}.")

      {:error, _} ->
        error_component(
          "An unknown error occurred while removing the friendship. Please try again."
        )
    end
  end

  @impl Nosedrum.ApplicationCommand
  def type, do: :slash

  @impl Nosedrum.ApplicationCommand
  def options,
    do: [
      %{
        name: "request",
        type: :sub_command_group,
        description: "Manages your friend requests.",
        options: [
          %{
            name: "send",
            description:
              "Sends a friend request to a system by their ID, Discord ping, or username.",
            type: :sub_command,
            options: [
              %{
                name: "system-id",
                type: :string,
                min_length: 7,
                max_length: 7,
                description: "The ID of the system to send a friend request to.",
                required: false
              },
              %{
                name: "username",
                type: :string,
                min_length: 5,
                max_length: 16,
                description: "The username of the system to send a friend request to.",
                required: false
              },
              %{
                name: "discord",
                description: "The Discord ping of the user to send a friend request to.",
                type: :user,
                required: false
              }
            ]
          },
          %{
            name: "accept",
            description:
              "Accepts a friend request from a system by their ID, Discord ping, or username.",
            type: :sub_command,
            options: [
              %{
                name: "system-id",
                type: :string,
                min_length: 7,
                max_length: 7,
                description: "The ID of the system whose friend request to accept.",
                required: false,
                autocomplete: true
              },
              %{
                name: "discord",
                description: "The Discord ping of the user whose friend request to accept.",
                type: :user,
                required: false
              }
            ]
          },
          %{
            name: "reject",
            description:
              "Rejects a friend request from a system by their ID, Discord ping, or username.",
            type: :sub_command,
            options: [
              %{
                name: "system-id",
                type: :string,
                min_length: 7,
                max_length: 7,
                description: "The ID of the system whose friend request to reject.",
                required: false,
                autocomplete: true
              },
              %{
                name: "discord",
                description: "The Discord ping of the user whose friend request to reject.",
                type: :user,
                required: false
              }
            ]
          },
          %{
            name: "cancel",
            description:
              "Cancels a friend request to a system by their ID, Discord ping, or username.",
            type: :sub_command,
            options: [
              %{
                name: "system-id",
                type: :string,
                min_length: 7,
                max_length: 7,
                description: "The ID of the system whose friend request to cancel.",
                required: false,
                autocomplete: true
              },
              %{
                name: "discord",
                description: "The Discord ping of the user whose friend request to cancel.",
                type: :user,
                required: false
              }
            ]
          },
          %{
            name: "list",
            description: "Lists your incoming and outgoing friend requests.",
            type: :sub_command
          }
        ]
      },
      %{
        name: "remove",
        description: "Removes a friend.",
        type: :sub_command,
        options: [
          %{
            name: "system-id",
            type: :string,
            min_length: 7,
            max_length: 7,
            description: "The ID of the system to remove as a friend.",
            required: false,
            autocomplete: true
          },
          %{
            name: "discord",
            description: "The Discord ping of the user to remove as a friend.",
            type: :user,
            required: false
          }
        ]
      },
      %{
        name: "list",
        description: "Lists your friends.",
        type: :sub_command
      },
      %{
        name: "trust",
        description: "Turns a friend into a \"trusted friend\".",
        type: :sub_command,
        options: [
          %{
            name: "system-id",
            type: :string,
            min_length: 7,
            max_length: 7,
            description: "The ID of the system to trust.",
            required: false,
            autocomplete: true
          },
          %{
            name: "discord",
            description: "The Discord ping of the user to trust.",
            type: :user,
            required: false
          }
        ]
      },
      %{
        name: "untrust",
        description: "Turns a \"trusted friend\" into a regular friend.",
        type: :sub_command,
        options: [
          %{
            name: "system-id",
            type: :string,
            min_length: 7,
            max_length: 7,
            description: "The ID of the system to untrust.",
            required: false,
            autocomplete: true
          },
          %{
            name: "discord",
            description: "The Discord ping of the user to untrust.",
            type: :user,
            required: false
          }
        ]
      }
    ]
end
