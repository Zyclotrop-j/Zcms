defimpl String.Chars, for: BSON.ObjectId do
  def to_string(object_id), do: Base.encode16(object_id.value, case: :lower)
end

defmodule Zcms.Loaders.Mongo do
  import Absinthe.Resolution.Helpers

  def loadMany(source, idmatchingfield) do
    fn r, args, %{context: %{loader: loader}} = res ->
      case r do
        %{_id: id} ->
          resource = res.definition.schema_node.identifier

          type =
            case Enum.find(res.path, fn x -> x.schema_node.identifier == resource end).schema_node.type do
              %{of_type: x} -> x
              val -> val
            end
            |> Atom.to_string()
            |> Macro.camelize()

          field =
            idmatchingfield
            |> Atom.to_string()

          argss = %{:coll => type, :field => {field, "$id"}, :rightHand => r._id}

          # # TODO: nesting for filterfn d[d] is %{}

          filterfn = fn d -> Map.keys(args) |> Enum.all?(fn u -> d[u] && d[u] == args[u] end) end

          loader
          |> Dataloader.load(source, type <> "By" <> field, argss)
          |> on_load(fn loader ->
            {:ok,
             Dataloader.get(loader, source, type <> "By" <> field, argss) |> Enum.filter(filterfn)}
          end)

        %{} ->
          []
      end
    end
  end

  def loadOne(source) do
    fn r, args, %{context: %{loader: loader}} = res ->
      resource = res.definition.schema_node.identifier

      if Map.has_key?(r, resource) do
        type =
          case Enum.find(res.path, fn x -> x.schema_node.identifier == resource end).schema_node.type do
            %{of_type: x} -> x
            val -> val
          end
          |> Atom.to_string()
          |> Macro.camelize()

        argss = %{:coll => type, :field => {"_id"}, :rightHand => r[resource][:"$id"]}

        filterfn = fn d -> Map.keys(args) |> Enum.all?(fn u -> d[u] && d[u] == args[u] end) end

        loader
        |> Dataloader.load(source, type <> "By_id", argss)
        |> on_load(fn loader ->
          {:ok,
           Dataloader.get(loader, source, type <> "By_id", argss)
           |> Enum.filter(filterfn)
           |> List.first()}
        end)
      else
        []
      end
    end
  end

  def data() do
    Dataloader.KV.new(&fetch/2)
  end

  def fetch(batch, args) do
    # %{ :coll => type, :field => field, :operator => (fn (a,b) -> a == b end), :rightHand => r._id }
    rHandVals =
      args
      |> Enum.map(fn arg -> arg.rightHand end)

    coll =
      args
      |> MapSet.to_list()
      |> List.first()

    # endable early exit if no rHandVals
    qresult =
      Mongo.find(
        :mongo,
        coll.coll,
        %{Enum.join(Tuple.to_list(coll.field), ".") => %{"$in" => rHandVals}},
        pool: DBConnection.Poolboy
      )

    args
    |> Enum.reduce(%{}, fn arg, acc ->
      Map.put(
        acc,
        arg,
        qresult
        |> Enum.filter(fn x ->
          Kernel.get_in(x, Tuple.to_list(coll.field)) == arg.rightHand
        end)
        |> Enum.map(&Zcms.Generic.Resolver.string_key_map_to_atom/1)
        |> Enum.to_list()
      )
    end)
  end
end
