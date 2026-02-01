defmodule OctoconDiscord.Components.AlterPaginator do
  @moduledoc false
  use GenServer

  alias Nostrum.Api

  import OctoconDiscord.Utils.{
    Components,
    CV2
  }

  @table :alter_paginators
  @page_size 10

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def page_size, do: @page_size

  def handle_init(_system_id, [], 0) do
    error_component("You don't have any alters, yet. Create one with `/alter create`!")
  end

  def handle_init(system_id, alters, alters_length) when alters_length <= @page_size do
    generate_response(
      %{
        system_id: system_id,
        alters: [
          Enum.map(alters, &Map.take(&1, [:id, :name, :pronouns, :discord_proxies, :alias]))
        ],
        uid: nil,
        current_page: 1,
        total_pages: 1,
        alters_length: alters_length
      },
      false
    )
    |> Keyword.put(:flags, cv2_flags())
  end

  def handle_init(system_id, alters, alters_length) do
    uid = :erlang.unique_integer([:positive])

    chunked_alters =
      alters
      |> Stream.map(&Map.take(&1, [:id, :name, :pronouns, :discord_proxies, :alias]))
      |> Enum.chunk_every(@page_size)

    total_pages = ceil(alters_length / @page_size)

    data = %{
      system_id: system_id,
      alters: chunked_alters,
      uid: uid,
      current_page: 1,
      total_pages: total_pages,
      alters_length: alters_length
    }

    :ets.insert(@table, {uid, data})

    # [TODO]: Possibly clean up correlations after a while?
    Process.send_after(__MODULE__, {:drop, uid}, :timer.minutes(5))

    generate_response(data)
    |> Keyword.put(:flags, cv2_flags())
  end

  defp generate_response(
         %{
           system_id: _system_id,
           uid: uid,
           alters: alters,
           alters_length: alters_length,
           current_page: current_page,
           total_pages: total_pages
         },
         include_components \\ true
       ) do
    prev_enabled = current_page > 1
    next_enabled = current_page < total_pages

    page_alters = Enum.at(alters, current_page - 1)

    [
      components:
        [
          container(
            [
              text(
                "## Your alters (#{alters_length})\n\nClick an alter's button to view more details."
              ),
              separator(spacing: :large),
              Enum.map(page_alters, fn alter ->
                [
                  section(
                    [
                      text("""
                      **#{alter.name || "Unnamed alter"}**#{case alter.pronouns do
                        nil -> ""
                        pronouns -> " (#{pronouns})"
                      end}
                      - ID: `#{alter.id}`#{case alter.alias do
                        nil -> ""
                        alias -> "  •  Alias: `#{alias}`"
                      end}
                      #{case alter.discord_proxies do
                        [] -> ""
                        nil -> ""
                        proxies -> "- Proxies: #{Enum.map_join(proxies, "  •  ", fn proxy -> "`#{proxy}`" end)}"
                      end}
                      """)
                    ],
                    button(
                      "alter|view|#{alter.id}",
                      :secondary,
                      emoji: %{name: "open", id: 1_464_866_849_052_426_252}
                    )
                  )
                ]
              end)
              # text(
              #                 Enum.map_join(page_alters, "\n", fn alter ->
              #   "- `#{alter.id}#{case alter.alias do
              #     nil -> ""
              #     alias -> "/#{alias}"
              #   end}`　**#{alter.name || "Unnamed alter"}**#{case alter.pronouns do
              #     nil -> ""
              #     pronouns -> " (#{pronouns})"
              #   end}　#{case alter.discord_proxies do
              #     [] -> ""
              #     nil -> ""
              #     proxies -> "#{Enum.map_join(proxies, ", ", fn proxy -> "`#{proxy}`" end)}"
              #   end}"
              # end)
              #   )
            ]
            |> List.flatten()
          ),
          if include_components do
            action_row([
              button(
                "alter-pag|prev|#{uid}",
                :secondary,
                label: "Previous",
                emoji: %{name: "back", id: 1_464_878_088_923_123_784},
                disabled: !prev_enabled
              ),
              button(
                "alter-pag|next|#{uid}",
                :secondary,
                label: "Next",
                emoji: %{name: "forward", id: 1_464_878_087_912_030_282},
                disabled: !next_enabled
              )
            ])
          else
            []
          end
        ]
        |> List.flatten()
    ]
  end

  def handle_interaction("prev", uid, interaction) do
    old_data =
      :ets.lookup(@table, uid)
      |> hd()
      |> elem(1)

    data = %{
      old_data
      | current_page: old_data.current_page - 1
    }

    :ets.insert(@table, {uid, data})

    Api.create_interaction_response(interaction, %{
      type: 7,
      data: generate_response(data) |> Enum.into(%{})
    })
  rescue
    _ ->
      Api.create_interaction_response(interaction, %{
        type: 7,
        data:
          error_component("This list has expired. Please run `/alter list` again.")
          |> Enum.into(%{})
          |> Map.drop([:flags])
      })
  end

  def handle_interaction("next", uid, interaction) do
    old_data =
      :ets.lookup(@table, uid)
      |> hd()
      |> elem(1)

    data = %{
      old_data
      | current_page: old_data.current_page + 1
    }

    :ets.insert(@table, {uid, data})

    Api.create_interaction_response(interaction, %{
      type: 7,
      data: generate_response(data) |> Enum.into(%{})
    })
  rescue
    _ ->
      Api.create_interaction_response(interaction, %{
        type: 7,
        data:
          error_component("This list has expired. Please run `/alter list` again.")
          |> Enum.into(%{})
          |> Map.drop([:flags])
      })
  end

  def drop(uid) do
    :ets.delete(@table, uid)
  end

  def init([]) do
    :ets.new(@table, [
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
    :ets.delete(@table, uid)
    {:noreply, state}
  end
end
