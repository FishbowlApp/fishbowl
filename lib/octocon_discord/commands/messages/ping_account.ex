defmodule OctoconDiscord.Commands.Messages.PingAccount do
  @moduledoc false

  @behaviour Nosedrum.ApplicationCommand

  alias OctoconDiscord.Utils

  alias Octocon.Messages

  @impl Nosedrum.ApplicationCommand
  def description, do: "Pings the account associated with a proxied message."

  @impl Nosedrum.ApplicationCommand
  def command(interaction) do
    %{
      data: %{
        resolved: %Nostrum.Struct.ApplicationCommandInteractionDataResolved{
          messages: messages
        }
      },
      user: %{
        id: user_id
      },
      guild_id: guild_id,
      channel_id: channel_id
    } = interaction

    [
      {message_id,
       %Nostrum.Struct.Message{
         author: %Nostrum.Struct.User{
           bot: is_bot
         }
       }}
    ] =
      messages
      |> Enum.map(& &1)

    if is_bot do
      case Messages.lookup_message(message_id) do
        nil ->
          Utils.error_component(
            "This message either:\n\n- Was not proxied by Octocon.\n- Is more than 6 months old."
          )

        message ->
          permalink = "https://discord.com/channels/#{guild_id}/#{channel_id}/#{message_id}"

          [
            components: [
              Utils.text("<@#{message.author_id}>"),
              Utils.container(
                [
                  Utils.text("### :bell: You've been pinged!"),
                  Utils.text(
                    if to_string(user_id) == to_string(message.author_id) do
                      "You have pinged yourself from a [proxied message](#{permalink})."
                    else
                      "<@#{user_id}> has pinged you from a [proxied message](#{permalink})."
                    end
                  )
                ],
                %{accent_color: Utils.hex_to_int("#3F3793")}
              )
            ],
            flags: Utils.cv2_flags(false)
          ]
      end
    else
      Utils.error_component("You can only do this with messages proxied by Octocon.")
    end
  end

  @impl Nosedrum.ApplicationCommand
  def type, do: :message
end
