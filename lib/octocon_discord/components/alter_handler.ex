defmodule OctoconDiscord.Components.AlterHandler do
  alias Nostrum.Api
  alias OctoconDiscord.Utils

  def handle_interaction("view", alter_id, interaction) do
    system_identity = {:discord, to_string(interaction.user.id)}

    alter =
      Octocon.Alters.get_alter_by_id!(system_identity, {:id, alter_id})

    fronts = Octocon.Fronts.currently_fronting(system_identity)

    Api.Interaction.create_response(interaction, %{
      type: 4,
      data: %{
        components: Utils.alter_component(alter, fronts, false),
        flags: Utils.cv2_flags()
      }
    })
  end
end
