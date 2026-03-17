defmodule Octocon.CachexChild do
  defmacro __using__(opts) do
    quote do
      @cachex_opts unquote(opts)

      def child_spec(extra_opts \\ []) do
        Supervisor.child_spec(
          {Cachex, Keyword.merge(@cachex_opts, extra_opts)},
          id: __MODULE__
        )
      end
    end
  end
end
