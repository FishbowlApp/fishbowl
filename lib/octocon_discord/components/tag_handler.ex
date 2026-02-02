defmodule OctoconDiscord.Components.TagHandler do
  import OctoconDiscord.Utils.Components

  alias Nostrum.Api

  alias Octocon.{
    Alters,
    Tags
  }

  def handle_interaction("view", tag_id, interaction) do
    system_identity = {:discord, to_string(interaction.user.id)}

    tag = Tags.get_tag(system_identity, tag_id)

    alters =
      Alters.get_alters_by_id_bounded(system_identity, tag.alters, [
        :id,
        :name,
        :pronouns,
        :security_level
      ])

    send_response(tag_component(tag, alters), interaction)
  end

  defp send_response(components, interaction) do
    Api.Interaction.create_response(interaction, %{
      type: 7,
      data: %{
        components: if(is_list(components), do: components, else: [components]),
        flags: OctoconDiscord.Utils.CV2.cv2_flags()
      }
    })
  end
end
