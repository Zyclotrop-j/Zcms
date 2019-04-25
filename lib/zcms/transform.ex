defmodule MalformedSchema do
  defexception message: "malformed json-schema"
end

defmodule Zcms.Application.Transformer do
  defp baseschema(),
    do: """
      defmodule ZcmsWeb.Schema do
        use Absinthe.Schema
        import Absinthe.Resolution.Helpers

        import_types(ZcmsWeb.Schema.{Types, Types.Custom.JSON})

        def context(ctx) do
          loader =
            Dataloader.new()
            |> Dataloader.add_source(:zmongo, Zcms.Loaders.Mongo.data())

          Map.put(ctx, :loader, loader)
        end

        def plugins do
          [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
        end

        query do
        end
      end
    """

  defp first(name),
    do: """
    defmodule ZcmsWeb.Schema.Types.#{String.capitalize(name)} do
      use Absinthe.Schema.Notation
      use Absinthe.Ecto, repo: Zcms.Repo

      import Absinthe.Resolution.Helpers
      import Zcms.Loaders.Mongo
    """

  defp schemafirst(types),
    do: """
      defmodule ZcmsWeb.Schema do
      use Absinthe.Schema
      import Absinthe.Resolution.Helpers

      import_types(ZcmsWeb.Schema.{Types, Types.Custom.JSON#{types}})

      def context(ctx) do
        loader =
          Dataloader.new()
          |> Dataloader.add_source(:zmongo, Zcms.Loaders.Mongo.data())

        Map.put(ctx, :loader, loader)
      end

      def plugins do
        [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
      end
    """

  defp schemalast(),
    do: """
      end
    """

  defp last(),
    do: """
      end
    """

  def compile(name, ct) do
    # {:ok, file} = File.open(name <> ".debug", [:write])
    # IO.binwrite(file, ct)
    # File.close(file)
    # Compile to memory!!!
    IO.puts("COMPILING #{name}")
    IO.inspect(ct)
    [{mod, _}] = Code.compile_string(ct)
    IO.puts("END - COMPILED #{name}")
    {:ok, mod}
  end

  # Insert initial schema-schema (aka meta-schema)
  @external_resource "priv/schema.json"
  @schema_contents File.read!("priv/schema.json")
  def schema_contents, do: @schema_contents

  def initMetaDB(conn1, conn2, conn3) do
    filename = "schema"

    ijson = Poison.decode!(schema_contents)

    json =
      ijson
      |> Map.put("meta_schema", ijson["$schema"])
      |> Map.put("meta_id", ijson["$id"])
      |> Map.update!("title", fn i -> Regex.replace(~r/ /, i, "") |> String.downcase() end)
      |> Map.drop(["$schema", "$id"])

    case conn1.("schema", %{"title" => json["title"]}) do
      {:ok, 1} -> :ok
      other -> conn2.("schema", json)
    end

    conn3.(%{
      "createIndexes" => "schema",
      "indexes" => [%{"key" => %{"title" => 1}, "unique" => true, "name" => "schemaByTitle"}]
    })
  end

  def transformSchema(conn) do
    cursor = conn.("schema", %{})

    schemasfromdb =
      cursor
      |> Enum.to_list()

    schemapath = "lib/zcms_web/schema/"
    schemafile = "schema.ex"

    testschema = hd(schemasfromdb)

    {queries, mutations, importtypes, mods} =
      Enum.reduce(schemasfromdb, {"", "", "", []}, fn json, {qq, mm, imt, modslist} ->
        filename = json["title"]

        {queries, mutations, queryinputtypes} =
          json
          |> query(filename)

        [_, add] =
          json
          |> parse(filename)

        {:ok, file} =
          compile(
            schemapath <> "#{filename}-result-types.ex",
            first(filename) <> add <> queryinputtypes <> last
          )

        # compile_string

        ttypes = "Types.#{String.capitalize(filename)}"

        {qq <> queries, mm <> mutations, imt <> ", " <> ttypes, [file | modslist]}
      end)

    r = """
    query do
      #{queries}
      mutation do
        #{mutations}
      end
    end
    """

    # somehow this errors with "Types must exist if referenced."
    #    ** (Absinthe.Schema.Error) Invalid schema:
    # nofile:127: Update_resume :resume is not defined in your schema
    # stacktrace: (zcms) lib/zcms/transform.ex:159: Zcms.Application.Transformer.transformSchema/1.
    a = :code.delete(Elixir.Absinthe.Schema)
    c = :code.delete(Elixir.ZcmsWeb.Schema)
    b = :code.purge(Elixir.Absinthe.Schema)
    d = :code.purge(Elixir.ZcmsWeb.Schema)
    a = :code.delete(Elixir.Absinthe.Schema)
    c = :code.delete(Elixir.ZcmsWeb.Schema)

    IO.inspect(a: a, b: b, c: c, d: d)
    # atomic_load
    # Code.compile_string
    {:ok, file} = compile(schemapath <> schemafile, schemafirst(importtypes) <> r <> schemalast)
    allnewmodules = [file | mods]
    IO.puts("allnewmodules")
    IO.inspect(allnewmodules)

    :ok
  end

  def query(%{"type" => "object", "properties" => p}, name) do
    {args, inputData} =
      p
      |> Enum.map(fn {k, v} ->
        case parse(v, k, true) do
          [nil, nil] ->
            {"", ""}

          [nil, data] ->
            {"", data}

          [type, data] ->
            {"""
             arg(:\"#{Macro.underscore(k)}\", #{type})
             """, data}
        end
      end)
      |> Enum.unzip()

    querys = """
      field :#{name}, :#{name} do
        arg(:_id, non_null(:id))
        resolve(&Zcms.Generic.Resolver.find/3)
      end
      field :#{name}s, list_of(:#{name}) do
        arg(:_id, :id)
        #{args |> Enum.join("    ")}
        resolve(&Zcms.Generic.Resolver.all/3)
      end
    """

    mutations = """
        field :create_#{name}, type: :#{name} do
          #{args |> Enum.join("    ")}
          resolve(&Zcms.Generic.Resolver.create/3)
        end

        field :update_#{name}, type: :#{name} do
          arg(:_id, non_null(:id))
          #{args |> Enum.join("    ")}
          resolve(&Zcms.Generic.Resolver.update/3)
        end

        field :delete_#{name}, type: :#{name} do
          arg(:_id, non_null(:id))
          resolve(&Zcms.Generic.Resolver.delete/3)
        end
    """

    {querys, mutations, inputData |> Enum.join("\n  ")}
  end

  defp match({k, v}, isQuery) do
    case parse(v, k, isQuery) do
      [nil, nil] -> {"", ""}
      [nil, data] -> {"", data}
      [type, data] -> {"field(:\"#{Macro.underscore(k)}\", #{type})", data}
    end
  end

  def parse(x, y), do: parse(x, y, false)

  def parse(%{"type" => "object", "properties" => p}, name, isQuery) do
    {fields, data} =
      p
      |> Enum.map(fn x -> match(x, isQuery) end)
      |> Enum.unzip()

    fields = fields |> Enum.join("\n  ")
    data = data |> Enum.join("\n")

    r = """
    object :#{Macro.underscore(name)} do
      field(:_id, :id)
      #{fields}
    end
    """

    additionalQueryData =
      (isQuery &&
         """
           input_object :input_#{Macro.underscore(name)} do
             field(:_id, :id)
             #{fields}
           end
         """) || r

    [":" <> ((isQuery && "input_") || "") <> Macro.underscore(name), additionalQueryData <> data]
  end

  def parse(%{"type" => "object", "additionalProperties" => additionalProperties}, name, _) do
    [":json", ""]
  end

  def parse(%{"type" => "object", "patternProperties" => patternProperties}, name, _) do
    [":json", ""]
  end

  def parse(%{"type" => "array", "items" => i}, name, isQuery) do
    case parse(i, name, isQuery) do
      [nil, nil] -> ["", ""]
      [nil, data] -> ["", data]
      [type, data] -> ["list_of(#{type})", data]
    end
  end

  def parse(%{"type" => "string"}, name, _) do
    [":string", ""]
  end

  def parse(%{"type" => "number"}, name, _) do
    [":float", ""]
  end

  def parse(%{"type" => "integer"}, name, _) do
    [":integer", ""]
  end

  def parse(%{"type" => "boolean"}, name, _) do
    [":boolean", ""]
  end

  def parse(%{"type" => "null"}, name, _) do
    [":null", ""]
  end

  def parse(%{"type" => "array"}, name, isQuery) do
    # Without items we don't know what the list is of
    [nil, nil]
  end

  def parse(%{"type" => other}, name, _) do
    raise MalformedSchema, message: "found unknow type #{other}"
  end

  def parse(%{"ref" => _, "type" => _}, name, _) do
    raise MalformedSchema, message: "found ref and type on same node - not allowed"
  end

  def parse(%{"ref" => ref}, name, _) do
    # TODO
    # get ref and process from there
    # ref.split("/").pop() -> name -> put that name to remember for recurse
    # put
    [nil, nil]
  end

  def parse(%{"enum" => enum}, name, _) do
    enum |> Enum.map(fn i -> "value #{i}" end) |> Enum.join("\n")

    r = """
    enum :enum_#{name} do
      #{enum}
    end
    """

    [":enum_#{name}", r]
  end

  def parse(%{"const" => const}, name, _) do
    # TODO
    [nil, nil]
  end

  def parse(%{"anyOf" => listofsubschema}, name, _) do
    # TODO
    # define union of listofsubschema
    [nil, nil]
  end

  def parse(%{"oneOf" => listofsubschema}, name, _) do
    # TODO
    # define union of listofsubschema
    # we can't enforce all items in union to be the same, must do this via validation
    [nil, nil]
  end

  def parse(%{"allOf" => listofsubschema}, name, _) do
    # TODO
    # ?????, maybe search for first one with type/enum/const?
    [nil, nil]
  end

  def parse(%{}, name, _) do
    [nil, nil]
  end

  def parse(True, name, _) do
    [nil, nil]
  end
end
