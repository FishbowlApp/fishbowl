defmodule OctoconDiscord.Components.HelpHandler.Pages.Faq.InviteOctocon do
  use OctoconDiscord.Components.HelpHandler.Pages

  def embeds do
    [
      %Embed{
        title: "#{Emojis.faq()} How do I invite Fishbowl to my server?",
        color: Utils.hex_to_int("#3F3793"),
        description: """
        So long as you have the proper permissions, you can invite Fishbowl to your server by clicking on my profile and then the `+ Add App` button!

        Fishbowl also provides some features meant for server administrators, like a proxy log channel and the ability to force the use of system tags. See the `/admin` command group in the `Command list` section of this help interface for more information!
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
