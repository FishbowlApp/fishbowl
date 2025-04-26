defmodule OctoconDiscord.Components.HelpHandler.Pages.CommandList.Front.RemoveMain do
  use OctoconDiscord.Components.HelpHandler.Pages

  def embeds do
    [
      %Embed{
        title: "#{Emojis.slashcommand()} `/front remove-main`",
        color: Utils.hex_to_int("#0FBEAA"),
        description: """
        The `/front remove-main` command removes the currently set main fronter.
        ### Usage
        ```
        /front remove-main
        ```
        """
      }
    ]
  end

  def components(uid) do
    [
      %{
        type: 1,
        components: [
          back_button("front_root", uid)
        ]
      }
    ]
  end
end
