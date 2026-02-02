defmodule OctoconDiscord.Commands.Tag do
  @moduledoc false

  use OctoconDiscord.Commands

  @behaviour Nosedrum.ApplicationCommand

  alias OctoconDiscord.Components.TagPaginator

  alias Octocon.{
    Accounts,
    Tags
  }

  @subcommands %{
    "create" => &__MODULE__.create/2,
    "delete" => &__MODULE__.delete/2,
    "view" => &__MODULE__.view/2,
    "security" => &__MODULE__.security/2,
    "list" => &__MODULE__.list/2,
    "set-parent" => &__MODULE__.set_parent/2,
    "remove-parent" => &__MODULE__.remove_parent/2,
    "edit" => &__MODULE__.edit/2,
    "random" => &__MODULE__.random/2,
    "add-alter" => &__MODULE__.add_alter/2,
    "remove-alter" => &__MODULE__.remove_alter/2
  }

  @impl Nosedrum.ApplicationCommand
  def description, do: "Manages your system's tags."

  @impl Nosedrum.ApplicationCommand
  def command(interaction) do
    %{data: %{resolved: resolved}, user: %{id: discord_id}} = interaction
    discord_id = to_string(discord_id)

    ensure_registered(discord_id, fn ->
      %{data: %{options: [%{name: name, options: options}]}} = interaction

      @subcommands[name].(
        %{resolved: resolved, system_identity: {:discord, discord_id}, discord_id: discord_id},
        options
      )
    end)
  end

  def create(%{system_identity: system_identity}, options) do
    name = get_command_option(options, "name")

    case Tags.create_tag(system_identity, name) do
      {:ok, _} ->
        success_component(
          "Successfully created tag **#{name}**! You can view it with `/tag view`.\n\n**Note:** This tag is currently private. You can change this with `/tag security`."
        )

      {:error, _} ->
        error_component("An unknown error occurred while creating the tag. Please try again.")
    end
  end

  def delete(%{system_identity: system_identity}, options) do
    tag_id = get_command_option(options, "tag")

    case Tags.delete_tag(system_identity, tag_id) do
      :ok ->
        success_component("Successfully deleted tag!")

      {:error, _} ->
        error_component("An unknown error occurred while deleting the tag. Please try again.")
    end
  end

  def view(%{system_identity: system_identity}, options) do
    tag_id = get_command_option(options, "tag")

    case Tags.get_tag(system_identity, tag_id) do
      nil ->
        error_component("That tag does not exist.")

      tag ->
        show = get_show_option(options)

        alters =
          Octocon.Alters.get_alters_by_id_bounded(system_identity, tag.alters, [
            :id,
            :name,
            :pronouns,
            :security_level
          ])

        [
          components: tag_component(tag, alters, show),
          flags: cv2_flags(!show)
        ]
    end
  end

  def random(%{system_identity: system_identity}, options) do
    case Tags.get_random_tag(system_identity) do
      nil ->
        error_component("You don't have any tags to choose from.")

      {:ok, tag} ->
        show = get_show_option(options)

        alters =
          Octocon.Alters.get_alters_by_id_bounded(system_identity, tag.alters, [
            :id,
            :name,
            :pronouns,
            :security_level
          ])

        [
          components: tag_component(tag, alters, show),
          flags: cv2_flags(!show)
        ]
    end
  end

  def list(%{system_identity: system_identity}, _options) do
    system_id = Accounts.id_from_system_identity(system_identity, :system)

    tags =
      Tags.get_tags({:system, system_id})
      |> Enum.sort_by(& &1.name)

    TagPaginator.handle_init(system_id, tags, length(tags))
  end

  def set_parent(%{system_identity: system_identity}, options) do
    tag_id = get_command_option(options, "tag")
    parent_tag_id = get_command_option(options, "parent_tag")

    case Tags.set_parent_tag(system_identity, tag_id, parent_tag_id) do
      :ok ->
        success_component("Successfully updated the tag's parent tag!")

      {:error, :not_found} ->
        error_component("The specified tag does not exist.")

      {:error, :tag_cycle} ->
        error_component(
          "Setting that parent tag would create a cycle. Please choose a different tag."
        )

      {:error, _} ->
        error_component("An unknown error occurred while updating the tag. Please try again.")
    end
  end

  def remove_parent(%{system_identity: system_identity}, options) do
    tag_id = get_command_option(options, "tag")

    case Tags.remove_parent_tag(system_identity, tag_id) do
      :ok ->
        success_component("Successfully removed the tag's parent tag!")

      {:error, :not_found} ->
        error_component("The specified tag does not exist.")

      {:error, _} ->
        error_component("An unknown error occurred while updating the tag. Please try again.")
    end
  end

  def add_alter(%{system_identity: system_identity}, options) do
    tag_id = get_command_option(options, "tag")
    idalias = get_command_option(options, "alter")

    with_id_or_alias(idalias, fn alter_identity ->
      case Tags.attach_alter_to_tag(system_identity, tag_id, alter_identity) do
        :ok ->
          success_component("Successfully added the alter to the tag!")

        {:error, :alter_not_found} ->
          error_component("You don't have an alter with the ID or alias **#{idalias}**.")

        {:error, _} ->
          error_component("An unknown error occurred while updating the tag. Please try again.")
      end
    end)
  end

  def remove_alter(%{system_identity: system_identity}, options) do
    tag_id = get_command_option(options, "tag")
    idalias = get_command_option(options, "alter")

    with_id_or_alias(idalias, fn alter_identity ->
      case Tags.detach_alter_from_tag(system_identity, tag_id, alter_identity) do
        :ok ->
          success_component("Successfully added the alter to the tag!")

        {:error, :alter_not_found} ->
          error_component("You don't have an alter with the ID or alias **#{idalias}**.")

        {:error, _} ->
          error_component("An unknown error occurred while updating the tag. Please try again.")
      end
    end)
  end

  def update_tag(
        %{system_identity: system_identity},
        tag_id,
        options,
        success_text,
        embed_tag \\ true
      ) do
    case options do
      map when map_size(map) == 0 ->
        error_component("You must provide at least one field to update.")

      _ ->
        case Tags.update_tag(system_identity, tag_id, options) do
          {:ok, tag} ->
            [
              components:
                if embed_tag do
                  alters =
                    Octocon.Alters.get_alters_by_id_bounded(system_identity, tag.alters, [
                      :id,
                      :name,
                      :pronouns,
                      :security_level
                    ])

                  [
                    success_component_raw(success_text),
                    tag_component(
                      tag,
                      alters,
                      false
                    )
                  ]
                else
                  [success_component_raw(success_text)]
                end
                |> List.flatten(),
              flags: cv2_flags()
            ]

          {:error, :not_found} ->
            error_component("You don't have a tag with ID **#{tag_id}**.")

          {:error, _} ->
            error_component("An unknown error occurred while updating the tag. Please try again.")
        end
    end
  end

  def edit(context, options) do
    tag_id = get_command_option(options, "tag")

    to_update =
      %{
        name: get_command_option(options, "name"),
        description: get_command_option(options, "description"),
        color: get_command_option(options, "color")
      }
      |> Map.filter(fn {_, v} -> v != nil end)

    # This is ugly, but it works.
    try do
      if Map.has_key?(to_update, :color) do
        case validate_hex_color(to_update[:color]) do
          :error ->
            throw("Invalid color. Please provide a valid hex code.")

          {:ok, new_color} ->
            update_tag(
              context,
              tag_id,
              Map.put(to_update, :color, "#" <> new_color),
              "Successfully edited tag!"
            )
        end
      else
        update_tag(
          context,
          tag_id,
          to_update,
          "Successfully edited tag!"
        )
      end
    catch
      e -> error_component(e)
    end
  end

  def security(context, options) do
    security_level = get_command_option(options, "level") |> String.to_existing_atom()

    tag_id = get_command_option(options, "tag")

    update_tag(
      context,
      tag_id,
      %{security_level: security_level},
      "Successfully updated this tag's security level!",
      true
    )
  end

  @impl Nosedrum.ApplicationCommand
  def type, do: :slash

  @impl Nosedrum.ApplicationCommand
  def options,
    do: [
      %{
        name: "create",
        description: "Creates a new tag.",
        type: :sub_command,
        options: [
          %{
            name: "name",
            type: :string,
            max_length: 100,
            description: "The name of the tag to create.",
            required: true
          }
        ]
      },
      %{
        name: "delete",
        description: "Deletes an existing tag.",
        type: :sub_command,
        options: [
          %{
            name: "tag",
            type: :string,
            max_length: 36,
            description: "The tag to delete.",
            required: true,
            autocomplete: true
          }
        ]
      },
      %{
        name: "view",
        description: "Views an existing tag.",
        type: :sub_command,
        options:
          [
            %{
              name: "tag",
              type: :string,
              max_length: 36,
              description: "The tag to view.",
              required: true,
              autocomplete: true
            }
          ]
          |> add_show_option()
      },
      %{
        name: "random",
        description: "Views a random tag.",
        type: :sub_command,
        options: add_show_option([])
      },
      %{
        name: "list",
        description: "Lists all of your tags.",
        type: :sub_command,
        options: []
      },
      %{
        name: "security",
        description: "Manages a tag's security level.",
        type: :sub_command,
        options: [
          %{
            name: "tag",
            type: :string,
            description: "The tag to update.",
            max_length: 36,
            required: true,
            autocomplete: true
          },
          %{
            name: "level",
            type: :string,
            description: "The security level to set the tag to.",
            required: true,
            choices: [
              %{name: "Private", value: "private"},
              %{name: "Trusted friends only", value: "trusted_only"},
              %{name: "Friends only", value: "friends_only"},
              %{name: "Public", value: "public"}
            ]
          }
        ]
      },
      %{
        name: "edit",
        description: "Edits an existing tag.",
        type: :sub_command,
        options: [
          %{
            name: "tag",
            type: :string,
            description: "The tag to update.",
            max_length: 36,
            required: true,
            autocomplete: true
          },
          %{
            name: "name",
            type: :string,
            max_length: 80,
            description: "The new name of the tag.",
            required: false
          },
          %{
            name: "description",
            type: :string,
            max_length: 3000,
            description: "The new description of the tag.",
            required: false
          },
          %{
            name: "color",
            type: :string,
            min_length: 6,
            max_length: 7,
            description: "The new color (hex code) of the tag.",
            required: false
          }
        ]
      },
      %{
        name: "set-parent",
        description: "Sets the parent tag of an existing tag.",
        type: :sub_command,
        options: [
          %{
            name: "tag",
            type: :string,
            description: "The tag to update.",
            max_length: 36,
            required: true,
            autocomplete: true
          },
          %{
            name: "parent_tag",
            type: :string,
            description: "The new parent tag.",
            max_length: 36,
            required: true,
            autocomplete: true
          }
        ]
      },
      %{
        name: "remove-parent",
        description: "Removes the parent tag of an existing tag.",
        type: :sub_command,
        options: [
          %{
            name: "tag",
            type: :string,
            description: "The tag to update.",
            max_length: 36,
            required: true,
            autocomplete: true
          }
        ]
      },
      %{
        name: "add-alter",
        description: "Adds an alter to a tag.",
        type: :sub_command,
        options: [
          %{
            name: "tag",
            type: :string,
            description: "The tag to update.",
            max_length: 36,
            required: true,
            autocomplete: true
          },
          %{
            name: "alter",
            type: :string,
            description: "The ID (or alias) of the alter to add to the tag.",
            max_length: 80,
            required: true,
            autocomplete: true
          }
        ]
      },
      %{
        name: "remove-alter",
        description: "Removes an alter from a tag.",
        type: :sub_command,
        options: [
          %{
            name: "tag",
            type: :string,
            description: "The tag to update.",
            max_length: 36,
            required: true,
            autocomplete: true
          },
          %{
            name: "alter",
            type: :string,
            description: "The ID (or alias) of the alter to remove from the tag.",
            max_length: 80,
            required: true,
            autocomplete: true
          }
        ]
      }
    ]
end
