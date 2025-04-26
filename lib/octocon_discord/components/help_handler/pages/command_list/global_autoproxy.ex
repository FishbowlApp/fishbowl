defmodule OctoconDiscord.Components.HelpHandler.Pages.CommandList.GlobalAutoproxy do
  use OctoconDiscord.Components.HelpHandler.Pages

  def embeds do
    [
      %Embed{
        title: "#{Emojis.slashcommand()} `/global-autoproxy`",
        color: Utils.hex_to_int("#0FBEAA"),
        description: """
        The `/global-autoproxy` command changes your **global** autoproxy mode. There are three modes:

        - **None**: No messages will be autoproxied (default).
        - **Latch**: Messages will be autoproxied as the *alter who proxied last*.
        - **Front**: Messages will be autoproxied as the *alter set as main front*. If no main front is set, messages will be proxied as the *current longest-fronting alter*.

        ⚠️ **Global autoproxying can be considered a privacy issue!** If you wish to set your autoproxy mode *for a specific server*, please use `/autoproxy` instead.
        ### Usage
        ```
        /autoproxy <mode>
        ```
        ### Parameters
        - `mode`: The autoproxy mode to set. Must be one of `none`, `latch`,  or `front`.
        """
      }
    ]
  end

  def components(uid) do
    [
      %{
        type: 1,
        components: [
          back_button("command_list", uid)
        ]
      }
    ]
  end
end
