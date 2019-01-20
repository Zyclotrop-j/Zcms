defmodule Zcms.Resource.Rest do
  @moduledoc """
  The Zcms context.
  """

  @doc """
  Returns the list of rests.

  ## Examples

      iex> list_rests()
      [%Rest{}, ...]

  """
  def list_rests(type, query \\ %{}, r \\ & &1, e \\ & &1) do
    r.(Mongo.find(:mongo, type, query, pool: DBConnection.Poolboy))
  end

  @doc """
  Gets a single rest.

  Raises if the Rest does not exist.

  ## Examples

      iex> get_rest!(123)
      %Rest{}

  """
  def get_rest(type, query, r \\ & &1, e \\ fn _, _, _ -> {:error, "Not found"} end) do
    case Mongo.find_one(:mongo, type, query, pool: DBConnection.Poolboy) do
      nil ->
        e.(type, query, nil)

      item ->
        r.(item)
    end
  end

  @doc """
  Creates a rest.

  ## Examples

      iex> create_rest(%{field: value})
      {:ok, %Rest{}}

      iex> create_rest(%{field: bad_value})
      {:error, ...}

  """
  def create_rest(
        type,
        argsmap,
        r \\ & &1,
        e \\ fn type, _, _ -> {:error, "Couldn't insert new #{type}"} end
      ) do
    case Mongo.insert_one(:mongo, type, argsmap, pool: DBConnection.Poolboy) do
      {:ok, %{:inserted_id => id}} -> r.(id)
      e -> e.(type, argsmap, e)
    end
  end

  defp updateError(type, id, _, %{:matched_count => 0, :modified_count => _}),
    do: {:error, "Couldn't #{type} with _id=#{id}"}

  defp updateError(type, id, _, %{:matched_count => 1, :modified_count => 0}),
    do: {:error, "#{type} #{id} already in right shape"}

  defp updateError(type, id, _, _), do: {:error, "Couldn't update #{type} with _id=#{id}"}

  @doc """
  Updates a rest.

  ## Examples

      iex> update_rest(rest, %{field: new_value})
      {:ok, %Rest{}}

      iex> update_rest(rest, %{field: bad_value})
      {:error, ...}

  """
  def update_rest(type, id, map, r \\ & &1, e \\ &updateError/4) do
    case Mongo.update_one(:mongo, type, %{:_id => BSON.ObjectId.decode!(id)}, %{"$set" => map},
           pool: DBConnection.Poolboy
         ) do
      {:ok, %{:matched_count => 1, :modified_count => 1}} ->
        r.(id)

      {:ok, a} ->
        e.(type, id, map, a)

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
  def delete_rest(type, id, r \\ & &1, e \\ &deleteError/3) do
    case Mongo.delete_one(
           :mongo,
           type,
           %{:_id => BSON.ObjectId.decode!(id)},
           pool: DBConnection.Poolboy
         ) do
      {:ok, %{:deleted_count => 1}} -> r.(nil)
      {:ok, a} -> e.(type, id, a)
      q -> e.(type, id, q)
    end
  end
end
