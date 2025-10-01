# defmodule Octocon.Repo do
#   use Ecto.Repo,
#     otp_app: :octocon,
#     adapter: Ecto.Adapters.Postgres
# end
defmodule Octocon.Repo do
  @regions [:nam, :eur, :ocn, :eas, :sam, :sas, :gdpr]
  @funs [
    "insert",
    "update",
    "delete",
    "delete_all",
    "get",
    "one",
    "all",
    "aggregate"
  ]

  use Ecto.Repo,
    otp_app: :octocon,
    adapter: Exandra

  alias Octocon.UserRegistryCache

  def region_list, do: @regions

  defmacro create_global_shim(verb_string) when is_binary(verb_string) do
    verb = String.to_atom(verb_string)
    func_name = String.to_atom("#{verb}_global")

    quote bind_quoted: [func_name: func_name, verb: verb] do
      def unquote(func_name)(struct_or_changeset, opts \\ []) do
        consistency = Keyword.get(opts, :consistency, :local_one)

        __MODULE__.unquote(verb)(
          struct_or_changeset,
          opts
          |> Keyword.put(:prefix, "global")
          |> Keyword.put(:consistency, consistency)
        )
      end
    end
  end

  defmacro create_nam_nt_shim(verb_string) when is_binary(verb_string) do
    verb = String.to_atom(verb_string)
    func_name = String.to_atom("#{verb}_nam_nt")

    quote bind_quoted: [func_name: func_name, verb: verb] do
      def unquote(func_name)(struct_or_changeset, opts \\ []) do
        consistency = Keyword.get(opts, :consistency, :local_one)

        __MODULE__.unquote(verb)(
          struct_or_changeset,
          opts
          |> Keyword.put(:prefix, "nam_nt")
          |> Keyword.put(:consistency, consistency)
        )
      end
    end
  end

  defmacro create_regional_shim(verb_string) when is_binary(verb_string) do
    verb = String.to_atom(verb_string)
    func_name = String.to_atom("#{verb}_regional")

    quote bind_quoted: [func_name: func_name, verb: verb] do
      def unquote(func_name)(struct_or_changeset, identifier, opts \\ [])

      def unquote(func_name)(struct_or_changeset, {:region, region}, opts)
          when is_binary(region) do
        unquote(func_name)(
          struct_or_changeset,
          {:region, String.to_existing_atom(region)},
          opts
        )
      end

      def unquote(func_name)(struct_or_changeset, {:region, region}, opts)
          when is_atom(region) and region in @regions do
        consistency = consistency_from_opts(opts, region)

        __MODULE__.unquote(verb)(
          struct_or_changeset,
          opts
          |> Keyword.put(:prefix, to_string(region))
          |> Keyword.put(:consistency, consistency)
        )
      end

      def unquote(func_name)(struct_or_changeset, {:user, system_identity}, opts) do
        region = UserRegistryCache.get_region(system_identity)

        if region == nil do
          nil
        else
          unquote(func_name)(
            struct_or_changeset,
            {:region, region},
            opts
          )
        end
      end
    end
  end

  for fun <- @funs do
    create_global_shim(verb)
    create_nam_nt_shim(verb)
    create_regional_shim(verb)
  end

  ### Manual shims

  def exists_regional?(struct_or_changeset, {:region, region}, opts \\ [])
      when is_binary(region) do
    exists_regional?(
      struct_or_changeset,
      String.to_existing_atom(region),
      opts
    )
  end

  def exists_regional?(struct_or_changeset, {:region, region}, opts \\ [])
      when is_atom(region) and region in @regions do
    consistency = consistency_from_opts(opts, region)

    __MODULE__.exists?(
      struct_or_changeset,
      opts
      |> Keyword.put(:prefix, to_string(region))
      |> Keyword.put(:consistency, consistency)
    )
  end

  def exists_regional?(struct_or_changeset, {:user, system_identity}, opts \\ [])
      when is_binary(user_id) do
    region = UserRegistryCache.get_region(system_identity)

    if region == nil do
      nil
    else
      exists_regional?(struct_or_changeset, {:region, region}, opts)
    end
  end

  def exists_global?(struct_or_changeset, opts \\ []) do
    __MODULE__.exists?(struct_or_changeset, Keyword.put(opts, :prefix, "global"))
  end

  def exists_nam_nt?(struct_or_changeset, opts \\ []) do
    __MODULE__.exists?(struct_or_changeset, Keyword.put(opts, :prefix, "nam_nt"))
  end

  def update_all_regional(struct_or_changeset, updates, {:region, region}, opts \\ [])
      when is_atom(region) and region in @regions do
    consistency = consistency_from_opts(opts, region)

    __MODULE__.update_all(
      struct_or_changeset,
      updates,
      opts
      |> Keyword.put(:prefix, to_string(region))
      |> Keyword.put(:consistency, consistency)
    )
  end

  def update_all_regional(struct_or_changeset, updates, {:user, system_identity}, opts \\ [])
      when is_binary(user_id) do
    region = UserRegistryCache.get_region(system_identity)

    if region == nil do
      nil
    else
      update_all_regional(struct_or_changeset, updates, {:region, region}, opts)
    end
  end

  def update_all_global(struct_or_changeset, updates, opts \\ []) do
    __MODULE__.update_all(struct_or_changeset, updates, Keyword.put(opts, :prefix, "global"))
  end

  def update_all_nam_nt(struct_or_changeset, opts \\ []) do
    __MODULE__.update_all(struct_or_changeset, updates, Keyword.put(opts, :prefix, "nam_nt"))
  end

  def insert_all_regional(module, inserts, {:region, region}, opts \\ [])
      when is_atom(region) and region in @regions do
    consistency = consistency_from_opts(opts, region)

    __MODULE__.insert_all(
      module,
      inserts,
      opts
      |> Keyword.put(:prefix, to_string(region))
      |> Keyword.put(:consistency, consistency)
    )
  end

  def insert_all_regional(module, inserts, {:user, system_identity}, opts \\ [])
      when is_binary(user_id) do
    region = UserRegistryCache.get_region(system_identity)

    if region == nil do
      nil
    else
      insert_all_regional(module, inserts, {:region, region}, opts)
    end
  end

  def insert_all_global(module, inserts, opts \\ []) do
    __MODULE__.insert_all(module, inserts, Keyword.put(opts, :prefix, "global"))
  end

  def insert_all_nam_nt(module, inserts, opts \\ []) do
    __MODULE__.insert_all(module, inserts, Keyword.put(opts, :prefix, "nam_nt"))
  end

  def consistency_from_opts(opts, region) do
    current_region = Octocon.ClusterUtils.current_db_region()

    cond do
      Keyword.has_key?(opts, :consistency) ->
        Keyword.get(opts, :consistency)

      region == :gdpr ->
        :one

      current_region == :nam or region == current_region ->
        :local_one

      true ->
        :one
    end
  end

  # @env Mix.env()
end
