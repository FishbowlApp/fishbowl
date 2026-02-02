defmodule OctoconDiscord.Utils.CV2 do
  def container(components, options \\ []) do
    %{
      type: 17,
      components: components
    }
    |> merge_options(options)
  end

  def section(components, accessory, options \\ []) do
    %{
      type: 9,
      components: components,
      accessory: accessory
    }
    |> merge_options(options)
  end

  def separator(options \\ []) do
    divider = Keyword.get(options, :divider, true)

    spacing =
      Keyword.get(options, :spacing, :small)
      |> case do
        :small -> 1
        :large -> 2
      end

    %{
      type: 14,
      divider: divider,
      spacing: spacing
    }
  end

  def thumbnail(url, options \\ []) do
    %{
      type: 11,
      media: %{url: url}
    }
    |> merge_options(options)
  end

  def action_row(components, options \\ []) do
    %{
      type: 1,
      components: components
    }
    |> merge_options(options)
  end

  def string_select(id, options_list, options \\ []) do
    %{
      type: 3,
      custom_id: id,
      options: options_list
    }
    |> merge_options(options)
  end

  def user_select(id, options \\ []) do
    %{
      type: 5,
      custom_id: id
    }
    |> merge_options(options)
  end

  def role_select(id, options \\ []) do
    %{
      type: 6,
      custom_id: id
    }
    |> merge_options(options)
  end

  def mentionable_select(id, options \\ []) do
    %{
      type: 7,
      custom_id: id
    }
    |> merge_options(options)
  end

  def channel_select(id, options \\ []) do
    %{
      type: 8,
      custom_id: id
    }
    |> merge_options(options)
  end

  def text(text, options \\ []) do
    %{
      type: 10,
      content: text
    }
    |> merge_options(options)
  end

  def button(id, style, options \\ []) do
    style =
      case style do
        :primary -> 1
        :secondary -> 2
        :success -> 3
        :danger -> 4
        :link -> 5
        :premium -> 6
        num when is_integer(num) and num in 1..6 -> num
        _ -> 2
      end

    %{
      type: 2,
      custom_id: id,
      style: style
    }
    |> merge_options(options)
  end

  def link_button(url, options \\ []) do
    %{
      type: 2,
      style: 5,
      url: url
    }
    |> merge_options(options)
  end

  def cv2_flags(ephemeral \\ true) do
    if ephemeral do
      Bitwise.bor(Bitwise.bsl(1, 15), Bitwise.bsl(1, 6))
    else
      Bitwise.bsl(1, 15)
    end
  end

  defp merge_options(defaults, options) do
    Map.merge(defaults, Enum.into(options, %{}))
  end
end
