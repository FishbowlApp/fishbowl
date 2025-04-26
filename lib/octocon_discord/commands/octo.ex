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

  @behaviour Nosedrum.ApplicationCommand


  alias OctoconDiscord.Utils

  @impl true
  def description, do: "Displays an all-in-one interface to interact with Octocon."

  @impl true
  def command(interaction) do
    %{guild_id: guild_id, user: %{id: discord_id}} = interaction
    guild_id = to_string(guild_id)
    discord_id = to_string(discord_id)

    Utils.ensure_registered(discord_id, fn ->
      system_identity = {:discord, discord_id}

      context = %__MODULE__.Context{
        initial_interaction: interaction,
        guild_id: guild_id,
        discord_id: discord_id,
        system_identity: system_identity
      }

      IO.inspect(context)

      Utils.success_embed("Test")
    end)
  end

  @impl true
  def type, do: :slash

  @impl true
  def options, do: []
end