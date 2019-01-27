defmodule Zcms.Resource.Rest do
  def map_keys(map, fun) do
    case map do
      %BSON.ObjectId{} ->
        map

      %{} ->
        for {key, val} <- map,
            into: %{},
            do: {fun.(key), map_keys(val, fun)}

      [_ | _] ->
        Enum.map(map, fn item -> map_keys(item, fun) end)

      val ->
        val
    end
  end

  @moduledoc """
  The Zcms context.
  """

  @doc """
  Returns the list of rests.

  ## Examples

      iex> list_rests()
      [%Rest{}, ...]

  """
  # TODO: HANDLE $ in key by rewrite -> $ not supported in GQL
  def list_rests(read_only_conn, type, query \\ %{}, r \\ & &1, e \\ & &1) do
    # TODO: Filter result by read rights
    r.(
      Mongo.find(:mongo, type, query, pool: DBConnection.Poolboy)
      |> Enum.map(fn i -> map_keys(i, fn i -> Regex.replace(~r/^_dlr_/, i, "$") end) end)
    )
  end

  @doc """
  Gets a single rest.

  Raises if the Rest does not exist.

  ## Examples

      iex> get_rest!(123)
      %Rest{}

  """
  def get_rest(
        read_only_conn,
        type,
        query,
        r \\ & &1,
        e \\ fn _, _, _ -> {:error, "Not found"} end
      ) do
    # TODO: Check read rights
    # TODO: Create table groups and put users in setup
    # TODO: Use redis to lookup users in groups table
    case Mongo.find_one(:mongo, type, query, pool: DBConnection.Poolboy) do
      nil ->
        e.(type, query, nil)

      item ->
        r.(item |> map_keys(fn i -> Regex.replace(~r/^_dlr_/, i, "$") end))
    end
  end

  defp createError(type, _, {:error, %Mongo.Error{:message => message, :code => code}}),
    do: {:error, "Couldn't insert new #{type}; (MongoDB Error #{code}): #{message}"}

  defp createError(type, _, _),
    do: {:error, "Couldn't insert new #{type}"}

  @doc """
  Creates a rest.

  ## Examples

      iex> create_rest(%{field: value})
      {:ok, %Rest{}}

      iex> create_rest(%{field: bad_value})
      {:error, ...}

  """
  def create_rest(
        read_only_conn,
        type,
        argsmap,
        r \\ & &1,
        e \\ &createError/3
      ) do
    # TODO: Check write rights on collection
    # TODO: Add current user to creator
    # TODO: Add current user to modified user
    # TODO: Add current timestamp to created
    # TODO: Add current timestamp to last modified
    case Mongo.insert_one(
           :mongo,
           type,
           argsmap |> map_keys(fn i -> Regex.replace(~r/^\$/, i, "_dlr_") end),
           pool: DBConnection.Poolboy
         ) do
      {:ok, %{:inserted_id => id}} ->
        if type == "schema" do
          :ok =
            Zcms.Application.Transformer.transformSchema(fn a, b ->
              Mongo.find(:mongo, a, b, pool: DBConnection.Poolboy)
            end)
        end

        r.(id)

      e ->
        e.(type, argsmap, e)
    end
  end

  defp updateError(type, id, _, %{:matched_count => 0, :modified_count => _}),
    do: {:error, "Couldn't find #{type} with _id=#{id}"}

  defp updateError(type, id, _, %{:matched_count => 1, :modified_count => 0}),
    do: {:error, "#{type} #{id} already in right shape"}

  defp updateError(type, id, _, {:error, %Mongo.Error{:message => message, :code => code}}),
    do: {:error, "Couldn't update #{type} with _id=#{id}; (MongoDB Error #{code}): #{message}"}

  defp updateError(type, id, _, _), do: {:error, "Couldn't update #{type} with _id=#{id}"}

  @doc """
  Updates a rest.

  ## Examples

      iex> update_rest(rest, %{field: new_value})
      {:ok, %Rest{}}

      iex> update_rest(rest, %{field: bad_value})
      {:error, ...}

  """
  def update_rest(read_only_conn, type, id, map, r \\ & &1, e \\ &updateError/4) do
    # TODO: Check write rights
    # TODO: Add current user to modified user
    # TODO: Add current timestamp to last Modified
    case Mongo.update_one(
           :mongo,
           type,
           %{:_id => BSON.ObjectId.decode!(id)},
           %{"$set" => map |> map_keys(fn i -> Regex.replace(~r/^\$/, i, "_dlr_") end)},
           pool: DBConnection.Poolboy
         ) do
      {:ok, %{:matched_count => 1, :modified_count => 1}} ->
        if type == "schema" do
          :ok =
            Zcms.Application.Transformer.transformSchema(fn a, b ->
              Mongo.find(:mongo, a, b, pool: DBConnection.Poolboy)
            end)
        end

        r.(id)

      {:ok, a} ->
        e.(type, id, map, a)

      q ->
        e.(type, id, map, q)
    end
  end

  def replace_rest(read_only_conn, type, id, map, r \\ & &1, e \\ &updateError/4) do
    # TODO: Check write rights
    # TODO: Add current user to modified user
    # TODO: Add current timestamp to last Modified

    metaschema = ZcmsWeb.RestController.loadAndConvertJsonSchema(type)
    # TODO: read rights from the metaschema

    if type == "schema" do
      %{"title" => title} =
        get_rest(read_only_conn, "schema", %{:_id => BSON.ObjectId.decode!(id)})

      if title == "schema" do
        raise "Cannot replace root-schema. Every new schema created is validated against it!"
      end
    end

    case Mongo.find_one_and_replace(
           :mongo,
           type,
           %{:_id => BSON.ObjectId.decode!(id)},
           map |> map_keys(fn i -> Regex.replace(~r/^\$/, i, "_dlr_") end),
           pool: DBConnection.Poolboy
         ) do
      {:ok, _} ->
        if type == "schema" do
          :ok =
            Zcms.Application.Transformer.transformSchema(fn a, b ->
              Mongo.find(:mongo, a, b, pool: DBConnection.Poolboy)
            end)
        end

        r.(id)

      q ->
        e.(type, id, map, q)
    end
  end

  defp deleteError(type, id, %{:deleted_count => 0}),
    do: {:error, "Didn't find #{type} with _id=#{id}"}

  defp deleteError(type, id, _),
    do: {:error, "Something went wrong deleting #{type} with _id=#{id}"}

  @doc """
  Deletes a Rest.

  ## Examples

      iex> delete_rest(rest)
      {:ok, %Rest{}}

      iex> delete_rest(rest)
      {:error, ...}

  """
  def delete_rest(read_only_conn, type, id, r \\ & &1, e \\ &deleteError/3) do
    # TODO: Check write rights
    # TODO: Add current user to modified user
    # TODO: Add current timestamp to last Modified
    if type == "schema" do
      %{"title" => title} =
        get_rest(read_only_conn, "schema", %{:_id => BSON.ObjectId.decode!(id)})

      if title == "schema" do
        raise "Cannot delete root-schema. Every new schema created is validated against it!"
      end

      ZcmsWeb.SchemaCache.clear(title)
      IO.puts("Cleared #{title} from caching table")
    end

    case Mongo.delete_one(
           :mongo,
           type,
           %{:_id => BSON.ObjectId.decode!(id)},
           pool: DBConnection.Poolboy
         ) do
      {:ok, %{:deleted_count => 1}} ->
        if type == "schema" do
          :ok =
            Zcms.Application.Transformer.transformSchema(fn a, b ->
              Mongo.find(:mongo, a, b, pool: DBConnection.Poolboy)
            end)
        end

        r.(nil)

      {:ok, a} ->
        e.(type, id, a)

      q ->
        e.(type, id, q)
    end
  end
end
