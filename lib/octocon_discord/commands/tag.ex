defmodule OctoconDiscord.Commands.Tag do
  @moduledoc false

  use OctoconDiscord.Commands

  @behaviour Nosedrum.ApplicationCommand

  alias OctoconDiscord.Components.TagPaginator

  alias Octocon.{
    Accounts,
    Alters,
    Tags
  }

  @subcommands %{
    "create" => &__MODULE__.create/2,
    "delete" => &__MODULE__.delete/2
    # "view" => &__MODULE__.view/2,
    # "security" => &__MODULE__.security/2,
    # "list" => &__MODULE__.list/2,
    # "edit" => &__MODULE__.edit/2,
    # "random" => &__MODULE__.random/2,
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

      {:error, e} ->
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
        # [
        #   components: Utils.tag_component(tag),
        #   flags: Utils.cv2_flags()
        # ]
        success_component("[TODO]: #{inspect(tag)}")
    end
  end

  # def random(%{system_identity: system_identity}, options) do
  #   case Tags.get_random_tag(system_identity) do
  #     nil ->
  #       Utils.error_component("You don't have any alters to choose from.")

  #     {:ok, alter} ->
  #       show = Utils.get_show_option(options)

  #       [
  #         components: Utils.alter_component(alter, false, show),
  #         flags: Utils.cv2_flags(!show)
  #       ]
  #   end
  # end

  # def list(%{system_identity: system_identity}, options) do
  #   system_id = Accounts.id_from_system_identity(system_identity, :system)

  #   sort =
  #     case Utils.get_command_option(options, "sort") do
  #       nil -> :id
  #       "id" -> :id
  #       "alphabetical" -> :alphabetical
  #     end

  #   alters =
  #     Alters.get_alters_by_id({:system, system_id}, [
  #       :id,
  #       :name,
  #       :pronouns,
  #       :discord_proxies,
  #       :alias
  #     ])

  #   sorted_alters =
  #     case sort do
  #       :id -> alters
  #       :alphabetical -> alters |> Enum.sort_by(& &1.name)
  #     end

  #   AlterPaginator.handle_init(system_id, sorted_alters, length(sorted_alters))
  # end

  # def update_alter(
  #       %{system_identity: system_identity},
  #       alter_identity,
  #       options,
  #       success_text,
  #       embed_alter \\ true
  #     ) do
  #   case options do
  #     map when map_size(map) == 0 ->
  #       Utils.error_component("You must provide at least one field to update.")

  #     _ ->
  #       case Alters.update_alter(system_identity, alter_identity, options) do
  #         :ok ->
  #           [
  #             components:
  #               if embed_alter do
  #                 [
  #                   Utils.success_component_raw(success_text),
  #                   Utils.alter_component(
  #                     Alters.get_alter_by_id!(system_identity, alter_identity),
  #                     false,
  #                     false
  #                   )
  #                 ]
  #               else
  #                 [Utils.success_component_raw(success_text)]
  #               end
  #               |> List.flatten(),
  #             flags: Utils.cv2_flags()
  #           ]

  #         {:error, :no_alter_id} ->
  #           Utils.error_component(
  #             "You don't have an alter with ID **#{elem(alter_identity, 1)}**."
  #           )

  #         {:error, :no_alter_alias} ->
  #           Utils.error_component(
  #             "You don't have an alter with alias **#{elem(alter_identity, 1)}**."
  #           )

  #         {:error, _} ->
  #           Utils.error_component(
  #             "An unknown error occurred while updating the alter. Please try again."
  #           )
  #       end
  #   end
  # end

  # def edit(%{system_identity: system_identity} = context, options) do
  #   with_id_or_alias(options, fn alter_identity ->
  #     to_update =
  #       %{
  #         name: Utils.get_command_option(options, "name"),
  #         pronouns: Utils.get_command_option(options, "pronouns"),
  #         description: Utils.get_command_option(options, "description"),
  #         proxy_name: Utils.get_command_option(options, "proxy-name"),
  #         color: Utils.get_command_option(options, "color"),
  #         alias: Utils.get_command_option(options, "alias")
  #       }
  #       |> Map.filter(fn {_, v} -> v != nil end)

  #     # This is ugly, but it works.
  #     try do
  #       if Map.has_key?(to_update, :alias) do
  #         if Alters.alias_taken?(system_identity, to_update[:alias]) do
  #           throw("You already have an alter with the alias **#{to_update[:alias]}**.")
  #         end

  #         case Utils.validate_alias(to_update[:alias]) do
  #           {:error, error} -> throw(error)
  #           {:alias, _} -> :ok
  #         end
  #       end

  #       if Map.has_key?(to_update, :color) do
  #         case Utils.validate_hex_color(to_update[:color]) do
  #           :error ->
  #             throw("Invalid color. Please provide a valid hex code.")

  #           {:ok, new_color} ->
  #             update_alter(
  #               context,
  #               alter_identity,
  #               Map.put(to_update, :color, "#" <> new_color),
  #               "Successfully edited alter with ID/alias **#{elem(alter_identity, 1)}**!"
  #             )
  #         end
  #       else
  #         update_alter(
  #           context,
  #           alter_identity,
  #           to_update,
  #           "Successfully edited alter with ID/alias **#{elem(alter_identity, 1)}**!"
  #         )
  #       end
  #     catch
  #       e -> Utils.error_component(e)
  #     end
  #   end)
  # end

  # def security(context, options) do
  #   with_id_or_alias(options, fn alter_identity ->
  #     security_level = Utils.get_command_option(options, "level") |> String.to_existing_atom()

  #     update_alter(
  #       context,
  #       alter_identity,
  #       %{security_level: security_level},
  #       "Successfully updated alter's security level!",
  #       true
  #     )
  #   end)
  # end

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
      # %{
      #   name: "random",
      #   description: "Views a random tag.",
      #   type: :sub_command,
      #   options: Utils.add_show_option([])
      # },
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
      }
    ]
end
