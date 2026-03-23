defmodule OctoconDiscord.Commands.Octo.Context do
  defstruct [
    :initial_interaction,
    :guild_id,
    :discord_id,
    :system_identity
  ]
end

defmodule OctoconDiscord.Commands.Octo do
  @moduledoc false

  use OctoconDiscord.Commands

  @behaviour Nosedrum.ApplicationCommand

  @impl Nosedrum.ApplicationCommand
  def description, do: "Displays an all-in-one interface to interact with Fishbowl."

  @impl Nosedrum.ApplicationCommand
  def command(_interaction) do
    # %{guild_id: guild_id, user: %{id: discord_id}} = interaction
    # guild_id = to_string(guild_id)
    # discord_id = to_string(discord_id)

    # ensure_registered(discord_id, fn ->
    #   system_identity = {:discord, discord_id}

    #   context = %__MODULE__.Context{
    #     initial_interaction: interaction,
    #     guild_id: guild_id,
    #     discord_id: discord_id,
    #     system_identity: system_identity
    #   }

    #   success_component("Test")
    # end)

    error_component("This command is under construction.")
  end

  @impl Nosedrum.ApplicationCommand
  def type, do: :slash

  @impl Nosedrum.ApplicationCommand
  def options, do: []
end
