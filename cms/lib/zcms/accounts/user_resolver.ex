defmodule Zcms.Accounts.UserResolver do
  alias Zcms.Accounts

  defp string_key_map_to_atom(string_key_map) do
    for {key, val} <- string_key_map, into: %{}, do: {String.to_atom(key), val}
  end

  def all(_args, _info) do
    IO.puts("Finding all")
    {:ok,  Mongo.find(:mongo, "AccountsUser", %{}, limit: 20, pool: DBConnection.Poolboy)
      |> Enum.map(&string_key_map_to_atom/1)
      |> Enum.to_list()}
  end

  def find(%{email: email}, _info) do
    IO.puts("Finding #{email}")
    case  Mongo.find_one(:mongo, "AccountsUser", %{email: email}, pool: DBConnection.Poolboy) do
      nil -> {:error, "User email #{email} not found!"}
      user -> {:ok, string_key_map_to_atom(user)}
    end
  end

  def find(%{_id: id}, _info) do
    IO.puts("Finding #{id}")
    case  Mongo.find_one(:mongo, "AccountsUser", %{_id: BSON.ObjectId.decode!(id)}, pool: DBConnection.Poolboy) do
      nil -> {:error, "User _id #{id} not found!"}
      user -> {:ok, string_key_map_to_atom(user)}
    end
  end

  def find(_args, _info) do
    IO.puts("AuthError?")
	  {:error, "Not Authorized"}
  end

  def create(params, _info) do
    Accounts.create_user(params)
  end
end
