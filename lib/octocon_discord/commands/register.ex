defmodule OctoconDiscord.Commands.Register do
  @moduledoc false

  use OctoconDiscord.Commands

  @behaviour Nosedrum.ApplicationCommand

  alias Octocon.Accounts

  @impl Nosedrum.ApplicationCommand
  def description, do: "Creates a system under your Discord account."

  @impl Nosedrum.ApplicationCommand
  def command(interaction) do

    %{


      id: discord_id


      # avatar: avatar_hash


    } = interaction.user





    discord_id = to_string(discord_id)





    if Accounts.user_exists?({:discord, discord_id}) do


      error_component("You're already registered.")


    else


      case Accounts.create_user_from_discord(


             discord_id


             # ,%{avatar_url: avatar_url}


           ) do


        {:ok, user} ->


          success_component(


            "You're registered! Your system ID is: **#{user.id}**\n\nCheck out the `/help` command to learn your way around our platform!\n\nSome tips on how to get started can be found in `/help` -> `FAQ` -> `How do I get started with the bot?`"


          )





        {:error, _} ->


          error_component(


            "An unknown error occurred while registering your system. Please try again."


          )


      end


    end
  end

  @impl Nosedrum.ApplicationCommand
  def type, do: :slash

  # @impl Nosedrum.ApplicationCommand
  # def options, do: []
end
