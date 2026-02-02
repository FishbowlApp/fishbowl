defmodule OctoconDiscord.Components.Paginator do
  defmacro __using__(opts) do
    page_size = Keyword.get(opts, :page_size, 10)
    noun = Keyword.get(opts, :noun)
    interaction_id = Keyword.get(opts, :interaction_id)
    create_command = Keyword.get(opts, :create_command)
    list_command = Keyword.get(opts, :list_command)

    quote do
      use GenServer

      alias Nostrum.Api

      import OctoconDiscord.Utils.{
        Components,
        CV2
      }

      alias OctoconDiscord.Utils.Emojis

      @page_size unquote(page_size)

      def start_link([]) do
        GenServer.start_link(__MODULE__, [], name: __MODULE__)
      end

      def page_size, do: @page_size

      def handle_init(_system_id, [], 0) do
        error_component(
          "You don't have any #{unquote(noun)}s, yet. Create one with `/#{unquote(create_command)}`!"
        )
      end

      def handle_init(system_id, items, items_length) when items_length <= @page_size do
        generate_response(
          %{
            system_id: system_id,
            items: [
              map_items(items)
            ],
            extra_data: generate_extra_data(items),
            items_length: items_length,
            uid: nil,
            current_page: 1,
            total_pages: 1
          },
          false
        )
        |> Keyword.put(:flags, cv2_flags())
      end

      def handle_init(system_id, items, items_length) do
        uid = :erlang.unique_integer([:positive])

        chunked_items =
          items
          |> map_items()
          |> Enum.chunk_every(@page_size)

        total_pages = ceil(items_length / @page_size)

        data = %{
          system_id: system_id,
          items: chunked_items,
          extra_data: generate_extra_data(items),
          items_length: items_length,
          uid: uid,
          current_page: 1,
          total_pages: total_pages
        }

        :ets.insert(__MODULE__, {uid, data})

        # [TODO]: Possibly clean up correlations after a while?
        Process.send_after(__MODULE__, {:drop, uid}, :timer.minutes(5))

        generate_response(data)
        |> Keyword.put(:flags, cv2_flags())
      end

      def generate_response(
            %{
              system_id: _system_id,
              uid: uid,
              items: items,
              items_length: items_length,
              current_page: current_page,
              total_pages: total_pages
            } = context,
            include_components \\ true
          ) do
        page_items = Enum.at(items, current_page - 1)

        [
          components:
            [
              generate_page(page_items, context),
              if include_components do
                pagination_buttons(context)
              else
                []
              end
            ]
            |> List.flatten()
        ]
      end

      def handle_interaction("first", uid, interaction) do
        old_data =
          :ets.lookup(__MODULE__, uid)
          |> hd()
          |> elem(1)

        data = %{
          old_data
          | current_page: 1
        }

        :ets.insert(__MODULE__, {uid, data})

        Api.create_interaction_response(interaction, %{
          type: 7,
          data: generate_response(data) |> Enum.into(%{})
        })
      rescue
        _ -> send_expired_response(interaction)
      end

      def handle_interaction("prev", uid, interaction) do
        old_data =
          :ets.lookup(__MODULE__, uid)
          |> hd()
          |> elem(1)

        data = %{
          old_data
          | current_page: old_data.current_page - 1
        }

        :ets.insert(__MODULE__, {uid, data})

        Api.create_interaction_response(interaction, %{
          type: 7,
          data: generate_response(data) |> Enum.into(%{})
        })
      rescue
        _ -> send_expired_response(interaction)
      end

      def handle_interaction("next", uid, interaction) do
        old_data =
          :ets.lookup(__MODULE__, uid)
          |> hd()
          |> elem(1)

        data = %{
          old_data
          | current_page: old_data.current_page + 1
        }

        :ets.insert(__MODULE__, {uid, data})

        Api.create_interaction_response(interaction, %{
          type: 7,
          data: generate_response(data) |> Enum.into(%{})
        })
      rescue
        _ -> send_expired_response(interaction)
      end

      def handle_interaction("last", uid, interaction) do
        old_data =
          :ets.lookup(__MODULE__, uid)
          |> hd()
          |> elem(1)

        data = %{
          old_data
          | current_page: old_data.total_pages
        }

        :ets.insert(__MODULE__, {uid, data})

        Api.create_interaction_response(interaction, %{
          type: 7,
          data: generate_response(data) |> Enum.into(%{})
        })
      rescue
        _ -> send_expired_response(interaction)
      end

      defp send_expired_response(interaction) do
        Api.create_interaction_response(interaction, %{
          type: 7,
          data:
            error_component(
              "This list has expired. Please run `/#{unquote(list_command)}` again."
            )
            |> Enum.into(%{})
            |> Map.drop([:flags])
        })
      end

      def pagination_buttons(%{
            uid: uid,
            current_page: current_page,
            total_pages: total_pages
          }) do
        prev_enabled = current_page > 1
        next_enabled = current_page < total_pages

        action_row([
          button(
            "#{unquote(interaction_id)}|first|#{uid}",
            :secondary,
            label: "First",
            emoji: Emojis.component_emoji(Emojis.first()),
            disabled: !prev_enabled
          ),
          button(
            "#{unquote(interaction_id)}|prev|#{uid}",
            :secondary,
            label: "Previous",
            emoji: Emojis.component_emoji(Emojis.back()),
            disabled: !prev_enabled
          ),
          button(
            "#{unquote(interaction_id)}|next|#{uid}",
            :secondary,
            label: "Next",
            emoji: Emojis.component_emoji(Emojis.forward()),
            disabled: !next_enabled
          ),
          button(
            "#{unquote(interaction_id)}|last|#{uid}",
            :secondary,
            label: "Last",
            emoji: Emojis.component_emoji(Emojis.last()),
            disabled: !next_enabled
          )
        ])
      end

      def drop(uid) do
        :ets.delete(__MODULE__, uid)
      end

      def init([]) do
        :ets.new(__MODULE__, [
          :set,
          :named_table,
          :public,
          read_concurrency: true,
          write_concurrency: :auto,
          decentralized_counters: true
        ])

        {:ok, %{}}
      end

      def handle_info({:drop, uid}, state) do
        :ets.delete(__MODULE__, uid)
        {:noreply, state}
      end
    end
  end
end
