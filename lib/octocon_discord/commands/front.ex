defmodule OctoconDiscord.Commands.Front do
  @moduledoc false

  use OctoconDiscord.Commands

  @behaviour Nosedrum.ApplicationCommand

  alias Octocon.{
    Accounts,
    Alters,
    Fronts
  }

  @subcommands %{
    "set" => &__MODULE__.set/2,
    "end" => &__MODULE__.endd/2,
    "add" => &__MODULE__.add/2,
    "view" => &__MODULE__.view/2,
    "main" => &__MODULE__.main/2,
    "remove-main" => &__MODULE__.remove_main/2
  }

  @impl Nosedrum.ApplicationCommand
  def description, do: "Manages which alters are in front."

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

  def view(%{system_identity: system_identity}, _options) do
    currently_fronting = Fronts.currently_fronting(system_identity)

    if currently_fronting == [] do
      error_component(
        "No alters are fronting! Use `/front add` to add alters to front, or `/front set` to set a single alter to front."
      )
    else
      [
        components: [
          container(
            [
              text("## Currently fronting alters (#{length(currently_fronting)})"),
              separator(spacing: :large),
              Enum.map(currently_fronting, fn %{front: front, alter: alter, primary: primary} ->
                inserted_at =
                  front.time_start |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()

                text("""
                #{if primary, do: ":star: ", else: ""}**#{alter.name || "Unnamed alter"}**#{case alter.pronouns do
                  nil -> ""
                  pronouns -> " (#{pronouns})"
                end}
                - ID: `#{alter.id}`#{case alter.alias do
                  nil -> ""
                  alias -> "  •  Alias: `#{alias}`"
                end}
                - Fronting since: <t:#{inserted_at}:R>
                #{if front.comment && front.comment != "",
                  do: "- Comment: #{front.comment}",
                  else: ""}
                """)
              end),
              separator(spacing: :large),
              text("*⭐ = Main front*")
            ]
            |> List.flatten()
          )
        ],
        flags: cv2_flags()
      ]
    end
  end

  def set(%{system_identity: system_identity}, options) do
    with_id_or_alias(options, fn alter_identity ->
      alter_id = Alters.resolve_alter(system_identity, alter_identity)

      if alter_id != false do
        comment = get_command_option(options, "comment") || ""
        set_main? = get_command_option(options, "set-main") || false

        case Fronts.set_front(system_identity, alter_identity, comment) do
          {:ok, _} ->
            if set_main? do
              Accounts.set_primary_front(system_identity, alter_id)
            end

            success_component(
              "This alter is now fronting. All other alters have been removed from front."
            )

          {:error, :already_fronting} ->
            error_component("This alter is already fronting.")

          {:error, _} ->
            error_component("An unknown error occurred.")
        end
      else
        case alter_identity do
          {:id, id} ->
            error_component("You don't have an alter with ID **#{id}**.")

          {:alias, aliaz} ->
            error_component("You don't have an alter with alias **#{aliaz}**.")
        end
      end
    end)
  end

  def add(%{system_identity: system_identity}, options) do
    with_id_or_alias(options, fn alter_identity ->
      alter_id = Alters.resolve_alter(system_identity, alter_identity)

      if alter_id != false do
        comment = get_command_option(options, "comment") || ""
        set_main? = get_command_option(options, "set-main") || false

        case Fronts.start_front(system_identity, alter_identity, comment) do
          {:ok, _} ->
            if set_main? do
              Accounts.set_primary_front(system_identity, alter_id)
            end

            success_component("This alter is now fronting.")

          {:error, :already_fronting} ->
            error_component("This alter is already fronting.")

          {:error, _} ->
            error_component("An unknown error occurred.")
        end
      else
        case alter_identity do
          {:id, id} ->
            error_component("You don't have an alter with ID **#{id}**.")

          {:alias, aliaz} ->
            error_component("You don't have an alter with alias **#{aliaz}**.")
        end
      end
    end)
  end

  def endd(%{system_identity: system_identity}, options) do
    with_id_or_alias(options, fn alter_identity ->
      alter_id = Alters.resolve_alter(system_identity, alter_identity)

      if alter_id != false do
        case Fronts.end_front(system_identity, alter_identity) do
          :ok ->
            success_component("Alter with ID **#{alter_id}** was removed from front.")

          {:error, :not_fronting} ->
            error_component("Alter with ID **#{alter_id}** is not currently fronting.")

          {:error, _} ->
            error_component("An unknown error occurred.")
        end
      else
        case alter_identity do
          {:id, id} ->
            error_component("You don't have an alter with ID **#{id}**.")

          {:alias, aliaz} ->
            error_component("You don't have an alter with alias **#{aliaz}**.")
        end
      end
    end)
  end

  def main(%{system_identity: system_identity}, options) do
    with_id_or_alias(options, fn alter_identity ->
      alter_id = Alters.resolve_alter(system_identity, alter_identity)

      if alter_id != false do
        if Fronts.fronting?(system_identity, alter_identity) do
          Accounts.set_primary_front(system_identity, alter_id)

          success_component("The alter with ID **#{alter_id}** is now set as main front.")
        else
          should_front = get_command_option(options, "add-to-front") || false

          if should_front do
            add(%{system_identity: system_identity}, [
              %Nostrum.Struct.ApplicationCommandInteractionDataOption{
                name: "set-main",
                value: true,
                type: 5
              }
              | options
            ])
          else
            error_component(
              "That alter is not currently fronting.\n\n-# Hint: rerun this command with the `add-to-front` option to add the alter to front *and* set them as main front in one go!"
            )
          end
        end
      else
        case alter_identity do
          {:id, id} ->
            error_component("You don't have an alter with ID **#{id}**.")

          {:alias, aliaz} ->
            error_component("You don't have an alter with alias **#{aliaz}**.")
        end
      end
    end)
  end

  def remove_main(%{system_identity: system_identity}, _options) do
    Accounts.set_primary_front(system_identity, nil)
    success_component("Removed main front.")
  end

  @impl Nosedrum.ApplicationCommand
  def type, do: :slash

  @impl Nosedrum.ApplicationCommand
  def options,
    do: [
      %{
        name: "view",
        description: "Views your currently fronting alters.",
        type: :sub_command
      },
      %{
        name: "add",
        description: "Adds an alter to front.",
        type: :sub_command,
        options: [
          %{
            name: "id",
            description: "The ID (or alias) of the alter to add to front.",
            type: :string,
            max_length: 80,
            required: true,
            autocomplete: true
          },
          %{
            name: "comment",
            description: "An optional comment to add to the front.",
            type: :string,
            max_length: 50,
            required: false
          },
          %{
            name: "set-main",
            description: "Whether to set the alter as main front.",
            type: :boolean,
            required: false
          }
        ]
      },
      %{
        name: "end",
        description: "Removes an alter from front.",
        type: :sub_command,
        options: [
          %{
            name: "id",
            description: "The ID (or alias) of the alter to end fronting.",
            type: :string,
            max_length: 80,
            required: true,
            autocomplete: true
          }
        ]
      },
      %{
        name: "set",
        description: "Sets an alter as front, replacing all other alters.",
        type: :sub_command,
        options: [
          %{
            name: "id",
            description: "The ID (or alias) of the alter to set to front.",
            type: :string,
            max_length: 80,
            required: true,
            autocomplete: true
          },
          %{
            name: "comment",
            description: "An optional comment to add to the front.",
            type: :string,
            max_length: 50,
            required: false
          },
          %{
            name: "set-main",
            description: "Whether to set the alter as main front.",
            type: :boolean,
            required: false
          }
        ]
      },
      %{
        name: "main",
        description: "Sets the main fronting alter.",
        type: :sub_command,
        options: [
          %{
            name: "id",
            description: "The ID (or alias) of the alter to set as main front.",
            type: :string,
            max_length: 80,
            required: true,
            autocomplete: true
          },
          %{
            name: "add-to-front",
            description: "Whether to add the alter to front if they are not already fronting.",
            type: :boolean,
            required: false
          }
        ]
      },
      %{
        name: "remove-main",
        description: "Removes the main fronting alter.",
        type: :sub_command
      }
    ]
end
