defmodule MalformedSchema do
  defexception message: "malformed json-schema"
end

defmodule Zcms.Application.Transformer do
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

      import_types(ZcmsWeb.Schema.{Types, Types.Custom.JSON, #{types}})

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

  def transformSchema(conn) do
    cursor = Mongo.find(conn, "Schema", %{})

    schemasfromdb =
      cursor
      |> Enum.to_list()

    schemapath = "lib/zcms_web/schema/"
    schemafile = "schema.ex"

    testschema = hd(schemasfromdb)

    {queries, mutations, importtypes} =
      Enum.reduce(schemasfromdb, {"", "", ""}, fn json, {qq, mm, imt} ->
        filename = json["title"]

        {queries, mutations, queryinputtypes} =
          json
          |> query(filename)

        [_, add] =
          json
          |> parse(filename)

        {:ok, file} = File.open(schemapath <> "#{filename}-result-types.ex", [:write])
        IO.binwrite(file, first(filename) <> add <> queryinputtypes <> last)
        File.close(file)

        ttypes = "Types.#{String.capitalize(filename)}"

        {qq <> queries, mm <> mutations, imt <> ttypes}
      end)

    case File.rm(schemapath <> schemafile) do
      :ok -> :ok
      {:error, :enoent} -> :ok
    end

    r = """
    query do
      #{queries}
      mutation do
        #{mutations}
      end
    end
    """

    {:ok, file} = File.open(schemapath <> schemafile, [:write])
    IO.binwrite(file, schemafirst(importtypes) <> r <> schemalast)
    File.close(file)

    :ok
  end

  def query(%{"type" => "object", "properties" => p}, name) do
    {args, inputData} =
      p
      |> Enum.map(fn {k, v} ->
        [type, data] = parse(v, k, true)

        {"""
         arg(:#{Macro.underscore(k)}, #{type})
         """, data}
      end)
      |> Enum.unzip()

    querys = """
      field :#{name}, :#{name} do
        arg(:_id, non_null(:id))
        resolve(&Zcms.Generic.Resolver.find/2)
      end
      field :#{name}s, list_of(:#{name}) do
        arg(:_id, :id)
        #{args |> Enum.join("    ")}
        resolve(&Zcms.Generic.Resolver.all/2)
      end
    """

    mutations = """
        field :create_#{name}, type: :#{name} do
          #{args |> Enum.join("    ")}
          resolve(&Zcms.Generic.Resolver.create/2)
        end

        field :update_#{name}, type: :#{name} do
          arg(:_id, non_null(:id))
          #{args |> Enum.join("    ")}
          resolve(&Zcms.Generic.Resolver.update/2)
        end

        field :delete_#{name}, type: :#{name} do
          arg(:_id, non_null(:id))
          resolve(&Zcms.Generic.Resolver.delete/2)
        end
    """

    {querys, mutations, inputData |> Enum.join("\n  ")}
  end

  defp match({k, v}, isQuery) do
    [type, data] = parse(v, k, isQuery)
    {"field(:#{Macro.underscore(k)}, #{type})", data}
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
    [type, data] = parse(i, name, isQuery)
    ["list_of(#{type})", data]
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
    [":json", ""]
  end

  def parse(%{"anyOf" => listofsubschema}, name, _) do
    # TODO
    # define union of listofsubschema
    [":union_....", ""]
  end

  def parse(%{"oneOf" => listofsubschema}, name, _) do
    # TODO
    # define union of listofsubschema
    # we can't enforce all items in union to be the same, must do this via validation
    [":union_....", ""]
  end

  def parse(%{"allOf" => listofsubschema}, name, _) do
    # TODO
    # ?????, maybe search for first one with type/enum/const?
    [":...", ""]
  end

  def parse(%{}, name, _) do
    [":json", ""]
  end

  def parse(True, name, _) do
    [":json", ""]
  end
end
