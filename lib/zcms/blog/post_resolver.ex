defmodule Zcms.Blog.PostResolver do

  defp string_key_map_to_atom(string_key_map) do
    for {key, val} <- string_key_map, into: %{}, do: {String.to_atom(key), val}
  end

  def all(_args,  _info) do
    type = (case _info.definition.schema_node.type do
      %{of_type: x} -> x
      val -> val
    end
      |> Atom.to_string
      |> Macro.camelize)
    {:ok,  Mongo.find(:mongo, type, %{}, limit: 20, pool: DBConnection.Poolboy)
      |> Enum.map(&string_key_map_to_atom/1)
      |> Enum.to_list()}
  end

  def find(argsmap, _info) do
    type = (case _info.definition.schema_node.type do
      %{of_type: x} -> x
      val -> val
    end
      |> Atom.to_string
      |> Macro.camelize)
    query = argsmap
      |> Enum.map(fn {k, v} -> {k, case v do
        _id -> BSON.ObjectId.decode!(v)
        val -> val
      end} end)
    case Mongo.find_one(:mongo, type, query, pool: DBConnection.Poolboy) do
      nil -> {:error, "Not found query " <> Enum.map(argsmap, fn({key, value}) -> "#{key}=#{value}" end) |> Enum.join("&")}
      post -> {:ok, string_key_map_to_atom(post)}
    end
  end

  def find(_args, _info) do
	  {:error, "Not Authorized"}
  end

  def create(args, %{context: %{current_user: _current_user}}) do
    Mongo.insert_one(:mongo, "Post", args, pool: DBConnection.Poolboy)
  end

  def create(_args, _info) do
	  {:error, "Not Authorized"}
  end

  def update(%{id: id, post: post_params}, %{context: %{current_user: _current_user}} = info) do
    case Mongo.replace_one(:mongo, "Post", %{_id: id}, post_params, pool: DBConnection.Poolboy) do
      {:ok, post} -> post
      {:error, _} -> {:error, "Post id #{id} not found"}
    end
  end

  def update(_args, _info) do
	  {:error, "Not Authorized"}
  end

  def delete(%{id: id}, %{context: %{current_user: _current_user}} = info) do
    case Mongo.delete_one(:mongo, "Post", %{_id: id}, pool: DBConnection.Poolboy) do
      {:ok, post} -> post
      {:error, _} -> {:error, "Post id #{id} not found"}
    end
  end

  def delete(_args, _info) do
	  {:error, "Not Authorized"}
  end
end
