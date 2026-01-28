defmodule OctoconDiscord.Components.AlterHandler do
  alias Nostrum.Api
  alias Octocon.Fronts
  alias OctoconDiscord.Utils

  def handle_interaction("view", alter_id, interaction) do
    system_identity = {:discord, to_string(interaction.user.id)}

    alter =
      Octocon.Alters.get_alter_by_id!(system_identity, {:id, alter_id})

    fronts = Fronts.currently_fronting(system_identity)

    send_response(Utils.alter_component(alter, fronts, false), interaction)
  end

  def handle_interaction("addfront", alter_id, interaction) do
    system_identity = {:discord, to_string(interaction.user.id)}

    case Fronts.start_front(system_identity, {:id, alter_id}) do
      {:ok, _} ->
        handle_interaction("view", alter_id, interaction)

      {:error, :already_fronting} ->
        Utils.error_component_raw("This alter is already fronting.")
        |> send_response(interaction)

      {:error, _} ->
        Utils.error_component_raw("An unknown error occurred.")
        |> send_response(interaction)
    end
  end

  def handle_interaction("removefront", alter_id, interaction) do
    system_identity = {:discord, to_string(interaction.user.id)}

    case Fronts.end_front(system_identity, {:id, alter_id}) do
      :ok ->
        handle_interaction("view", alter_id, interaction)

      {:error, :not_fronting} ->
        Utils.error_component_raw("This alter is not currently fronting.")
        |> send_response(interaction)

      {:error, _} ->
        Utils.error_component_raw("An unknown error occurred.")
        |> send_response(interaction)
    end
  end

  def handle_interaction("setfront", alter_id, interaction) do
    system_identity = {:discord, to_string(interaction.user.id)}

    case Fronts.set_front(system_identity, {:id, alter_id}) do
      {:ok, _} ->
        handle_interaction("view", alter_id, interaction)

      {:error, :already_fronting} ->
        Utils.error_component_raw("This alter is already fronting.")
        |> send_response(interaction)

      {:error, _} ->
        Utils.error_component_raw("An unknown error occurred.")
        |> send_response(interaction)
    end
  end

  def handle_interaction("setprimary", alter_id, interaction) do
    system_identity = {:discord, to_string(interaction.user.id)}

    if Fronts.fronting?(system_identity, {:id, alter_id}) do
      Octocon.Accounts.set_primary_front(system_identity, alter_id)

      handle_interaction("view", alter_id, interaction)
    else
      Utils.error_component_raw("This alter is not currently fronting.")
      |> send_response(interaction)
    end
  end

  def handle_interaction("removeprimary", alter_id, interaction) do
    system_identity = {:discord, to_string(interaction.user.id)}

    if Fronts.fronting?(system_identity, {:id, alter_id}) do
      Octocon.Accounts.set_primary_front(system_identity, nil)

      handle_interaction("view", alter_id, interaction)
    else
      Utils.error_component_raw("This alter is not currently fronting.")
      |> send_response(interaction)
    end
  end

  defp send_response(components, interaction) do
    Api.Interaction.create_response(interaction, %{
      type: 7,
      data: %{
        components: if(is_list(components), do: components, else: [components]),
        flags: Utils.cv2_flags()
      }
    })
  end
end
