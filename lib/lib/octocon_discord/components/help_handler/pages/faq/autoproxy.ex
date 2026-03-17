defmodule OctoconDiscord.Components.HelpHandler.Pages.Faq.Autoproxy do
  use OctoconDiscord.Components.HelpHandler.Pages

  def embeds do
    [
      %Embed{
        title: "#{Emojis.faq()} How does autoproxy work?",
        color: Utils.hex_to_int("#3F3793"),
        description: """
        Autoproxy is a feature in Octocon that allows you to automatically proxy as an alter when you send a message, without having to specify their proxy every time. There are three autoproxy modes:

        - **None**: No messages will be autoproxied (default).
        - **Latch**: Messages will be autoproxied as the *alter who proxied last*.
        - **Front**: Messages will be autoproxied as the *alter set as main front*. If no main front is set, messages will be proxied as the *current longest-fronting alter*.

        You can change your autoproxy mode using one of the following commands:
        - `/autoproxy` sets your server-specific autoproxy mode, which only applies to the server you ran the command in.
        - `/global-autoproxy` sets your global autoproxy mode, which applies to ***all servers*** the Octocon bot has been added to.

        ⚠️ Please note that **global autoproxying can be considered a privacy issue!**
        """
      }
    ]
  end

  def components(uid) do
    [
      %{
        type: 1,
        components: [
          back_button("faq_root", uid)
        ]
      }
    ]
  end
end
