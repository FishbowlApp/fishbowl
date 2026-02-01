defmodule OctoconDiscord.Commands do
  defmacro __using__(_opts) do
    quote do
      import OctoconDiscord.Utils

      import OctoconDiscord.Utils.{
        Commands,
        Components,
        CV2
      }
    end
  end
end
