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

          argss = %{
            :coll => type,
            :field => {field, "$id"},
            :rightHand => r._id,
            :conn => res.context.conn
          }

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

  def loadArray(source) do
    fn r, args, %{context: %{loader: loader}} = res ->
      # This is list?
      resource = res.definition.schema_node.identifier

      if Map.has_key?(r, resource) do
        # type = res.definition.schema_node.type.of_type
        type =
          case Enum.find(res.path, fn x -> x.schema_node.identifier == resource end).schema_node.type do
            %{of_type: x} -> x
            val -> val
          end
          |> Atom.to_string()

        # delete me
        etcslookup = :ets.lookup(:typemapping, type)

        oldtype =
          case type do
            "union_" <> _ ->
              type
              |> String.split("_")
              |> Enum.slice(1..-2)
              |> Enum.map(&Macro.camelize/1)

            _ ->
              type |> Macro.camelize()
          end

        type =
          case type |> String.length() > 240 && :ets.lookup(:typemapping, type) do
            [{^type, xt}] ->
              xt |> Enum.map(&Macro.camelize/1)

            _ ->
              case type do
                "union_" <> _ ->
                  type
                  |> String.split("_")
                  |> Enum.slice(1..-2)
                  |> Enum.map(&Macro.camelize/1)

                _ ->
                  type |> Macro.camelize()
              end
          end

        rh =
          if is_map(r[resource]) && Map.has_key?(r[resource], :"$id"),
            do: r[resource][:"$id"],
            else: r[resource]

        filterfn = fn d ->
          Map.keys(args) |> Enum.all?(fn u -> d[u] && d[u] == args[u] end)
        end

        cond do
          is_binary(type) ->
            argss =
              rh
              |> Enum.map(fn q ->
                %{:coll => type, :field => {"_id"}, :rightHand => q, :conn => res.context.conn}
              end)

            loader
            |> Dataloader.load_many(source, type <> "By_id", argss)
            |> on_load(fn loader ->
              w = Dataloader.get_many(loader, source, type <> "By_id", argss)

              {:ok,
               w
               |> Enum.map(fn x -> x |> Enum.filter(filterfn) end)
               |> Enum.map(fn x -> x |> List.first() end)}
            end)

          is_list(type) ->
            type
            |> Enum.reduce(loader, fn x, acc ->
              acc
              |> Dataloader.load_many(
                source,
                x <> "By_id",
                rh
                |> Enum.map(fn q ->
                  %{:coll => x, :field => {"_id"}, :rightHand => q, :conn => res.context.conn}
                end)
              )
            end)
            |> on_load(fn loader ->
              wq =
                type
                |> Enum.map(fn x ->
                  Dataloader.get_many(
                    loader,
                    source,
                    x <> "By_id",
                    rh
                    |> Enum.map(fn q ->
                      %{:coll => x, :field => {"_id"}, :rightHand => q, :conn => res.context.conn}
                    end)
                  )
                  |> Enum.filter(filterfn)
                end)
                |> List.flatten()
                # We need to sort this into the order the original id-array was in
                |> Enum.sort(fn a, b ->
                  Enum.find_index(rh, fn x -> x == a[:"x-id"] end) <
                    Enum.find_index(rh, fn x -> x == b[:"x-id"] end)
                end)

              {:ok, wq}
            end)
        end
      else
        []
      end
    end
  end

  def loadOne(source) do
    fn r, args, %{context: %{loader: loader}} = res ->
      resource = res.definition.schema_node.identifier

      # resource :cta
      # r %{ "cta": "..." }
      if Map.has_key?(r, resource) || Map.has_key?(r, Atom.to_string(resource)) do
        type =
          case Enum.find(res.path, fn x ->
                 x.schema_node.identifier == resource ||
                   x.schema_node.identifier == Atom.to_string(resource)
               end).schema_node.type do
            %{of_type: x} -> x
            val -> val
          end
          |> Atom.to_string()

        type =
          case type do
            "union_" <> _ ->
              type
              |> String.split("_")
              |> Enum.slice(1..-2)
              |> Enum.map(&Macro.camelize/1)

            _ ->
              type |> Macro.camelize()
          end

        tmp =
          cond do
            Map.has_key?(r, resource) -> r[resource]
            Map.has_key?(r, Atom.to_string(resource)) -> r[Atom.to_string(resource)]
            true -> r[Atom.to_string(resource)]
          end

        rh = if is_binary(tmp), do: tmp, else: tmp[:"$id"]

        cond do
          rh == nil ->
            {:ok, nil}

          rh == "" ->
            {:ok, nil}

          is_binary(type) ->
            argss = %{
              :coll => type,
              :field => {"_id"},
              :rightHand => rh,
              :conn => res.context.conn
            }

            filterfn = fn d ->
              Map.keys(args) |> Enum.all?(fn u -> d[u] && d[u] == args[u] end)
            end

            loader
            |> Dataloader.load(source, type <> "By_id", argss)
            |> on_load(fn loader ->
              answer = Dataloader.get(loader, source, type <> "By_id", argss)

              cond do
                answer == nil ->
                  backup =
                    Zcms.Resource.Rest.get_rest(
                      res.context.conn,
                      type |> String.downcase(),
                      %{"_id" => BSON.ObjectId.decode!(rh)}
                    )

                  IO.puts("Error - batch loader failed to load")
                  IO.puts("Falling back to individual loading")
                  IO.inspect(argss)
                  IO.inspect(type)
                  IO.inspect(rh)
                  IO.inspect(backup)
                  {:ok, backup}

                true ->
                  {:ok, answer |> Enum.filter(filterfn) |> List.first()}
              end
            end)

          is_list(type) ->
            argss =
              type
              |> Enum.map(fn q ->
                %{:coll => q, :field => {"_id"}, :rightHand => rh, :conn => res.context.conn}
              end)

            filterfn = fn d ->
              Map.keys(args) |> Enum.all?(fn u -> d[u] && d[u] == args[u] end)
            end

            argss
            |> Enum.reduce(loader, fn x, acc ->
              acc |> Dataloader.load(source, x.coll <> "By_id", x)
            end)
            |> on_load(fn loader ->
              wq =
                argss
                |> Enum.map(fn x ->
                  Dataloader.get(loader, source, x.coll <> "By_id", x)
                  |> Enum.filter(filterfn)
                  |> List.first()
                end)
                |> Enum.find_value(& &1)

              {:ok, wq}
            end)
        end
      else
        {:ok, nil}
      end
    end
  end

  def data() do
    Dataloader.KV.new(&fetch/2)
  end

  def fetch(batch, args) do
    # %{ :coll => type, :field => field, :operator => (fn (a,b) -> a == b end), :rightHand => r._id }

    conn =
      args
      |> Enum.map(fn arg -> arg.conn end)
      |> Enum.at(0)

    coll =
      args
      |> MapSet.to_list()
      |> List.first()

    field = Enum.join(Tuple.to_list(coll.field), ".")

    conv =
      if field == "_id",
        do: fn x ->
          case x do
            nil -> nil
            "" -> ""
            _ -> BSON.ObjectId.decode!(x)
          end
        end,
        else: & &1

    rHandVals =
      args
      |> Enum.map(fn arg -> arg.rightHand end)
      |> Enum.map(conv)

    # %{assigns: %{joken_claims: %{"sub" => sub}}},

    qresult =
      Zcms.Resource.Rest.list_rests(
        conn,
        coll.coll |> String.downcase(),
        %{field => %{"$in" => rHandVals}}
      )

    args
    |> Enum.reduce(%{}, fn arg, acc ->
      Map.put(
        acc,
        arg,
        qresult
        |> Enum.filter(fn x ->
          Kernel.get_in(x, Tuple.to_list(coll.field)) == conv.(arg.rightHand)
        end)
        |> Enum.map(&Zcms.Generic.Resolver.string_key_map_to_atom/1)
        |> Enum.to_list()
      )
    end)
  end
end
