defmodule Zcms.Generic.Resolver do
  alias Zcms.Accounts

  def string_key_map_to_atom(string_key_map) do
    case string_key_map do
      # unfortunately a map, but doesn't implement enumerable
      %BSON.ObjectId{} ->
        string_key_map

      %{} ->
        for {key, val} <- string_key_map,
            into: %{},
            do: {String.to_atom(key), string_key_map_to_atom(val)}

      val ->
        val
    end
  end

  def atom_key_map_to_string(atom_key_map) do
    case atom_key_map do
      %{} ->
        for {key, val} <- atom_key_map,
            into: %{},
            do: {Atom.to_string(key), atom_key_map_to_string(val)}

      val ->
        val
    end
  end

  defp inner_flatten_to_json_path(map) when is_binary(map), do: [{:ok, map}]

  defp f1(_, k, {:ok, v}) when k == :_id, do: {Atom.to_string(k), BSON.ObjectId.decode!(v)}
  defp f1(_, k, {:ok, v}), do: {Atom.to_string(k), v}
  defp f1(s, k, {h, t}), do: {Atom.to_string(k) <> s <> h, t}

  defp inner_flatten_to_json_path(map) do
    Enum.reduce(map, [], fn {k, v}, acc ->
      acc ++
        (inner_flatten_to_json_path(v)
         |> Enum.map(fn x -> f1(".", k, x) end))
    end)
  end

  def flatten_to_json_path(map) do
    inner_flatten_to_json_path(map)
    |> Enum.into(%{})
  end

  # def string_key_map_to_atom(string_key_map) do
  #  for {key, val} <- string_key_map, into: %{}, do: {String.to_atom(key), val}
  # end

  def all(argsmap, _info) do
    type =
      case _info.definition.schema_node.type do
        %{of_type: x} -> x
        val -> val
      end
      |> Atom.to_string()
      |> Macro.camelize()

    query = flatten_to_json_path(argsmap)

    Zcms.Resource.Rest.list_rests(type, query, fn i ->
      {:ok, i |> Enum.map(&string_key_map_to_atom/1) |> Enum.to_list()}
    end)
  end

  def find(argsmap, _info) do
    type =
      case _info.definition.schema_node.type do
        %{of_type: x} -> x
        val -> val
      end
      |> Atom.to_string()
      |> Macro.camelize()

    query = flatten_to_json_path(argsmap)

    Zcms.Resource.Rest.get_rest(
      type,
      query,
      fn item -> {:ok, string_key_map_to_atom(item)} end,
      fn ->
        {:error,
         ("Not found query " <> Enum.map(argsmap, fn {key, value} -> "#{key}=#{value}" end))
         |> Enum.join("&")}
      end
    )
  end

  def create(argsmap, info) do
    type =
      case info.definition.schema_node.type do
        %{of_type: x} -> x
        val -> val
      end
      |> Atom.to_string()
      |> Macro.camelize()

    Zcms.Resource.Rest.create_rest(type, argsmap, info, fn id ->
      find(%{:_id => BSON.ObjectId.encode!(id)}, info)
    end)
  end

  def update(argsmap, info) do
    type =
      case info.definition.schema_node.type do
        %{of_type: x} -> x
        val -> val
      end
      |> Atom.to_string()
      |> Macro.camelize()

    {id, map} = Map.pop(argsmap, :_id)

    Zcms.Resource.Rest.update_rest(type, id, map, fn _ -> find(%{:_id => id}, info) end)
  end

  def delete(argsmap, _info) do
    type =
      case _info.definition.schema_node.type do
        %{of_type: x} -> x
        val -> val
      end
      |> Atom.to_string()
      |> Macro.camelize()

    id = argsmap._id

    Zcms.Resource.Rest.delete_rest(type, id, fn _ -> {:ok, nil} end)
  end
end
