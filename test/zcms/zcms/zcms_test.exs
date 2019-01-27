defmodule Zcms.ZcmsTest do
  use Zcms.DataCase

  alias Zcms.Zcms

  describe "rests" do
    alias Zcms.Zcms.Rest

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def rest_fixture(attrs \\ %{}) do
      {:ok, rest} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Zcms.create_rest()

      rest
    end

    test "list_rests/0 returns all rests" do
      rest = rest_fixture()
      assert Zcms.list_rests() == [rest]
    end

    test "get_rest!/1 returns the rest with given id" do
      rest = rest_fixture()
      assert Zcms.get_rest!(rest.id) == rest
    end

    test "create_rest/1 with valid data creates a rest" do
      assert {:ok, %Rest{} = rest} = Zcms.create_rest(@valid_attrs)
    end

    test "create_rest/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Zcms.create_rest(@invalid_attrs)
    end

    test "update_rest/2 with valid data updates the rest" do
      rest = rest_fixture()
      assert {:ok, rest} = Zcms.update_rest(rest, @update_attrs)
      assert %Rest{} = rest
    end

    test "update_rest/2 with invalid data returns error changeset" do
      rest = rest_fixture()
      assert {:error, %Ecto.Changeset{}} = Zcms.update_rest(rest, @invalid_attrs)
      assert rest == Zcms.get_rest!(rest.id)
    end

    test "delete_rest/1 deletes the rest" do
      rest = rest_fixture()
      assert {:ok, %Rest{}} = Zcms.delete_rest(rest)
      assert_raise Ecto.NoResultsError, fn -> Zcms.get_rest!(rest.id) end
    end

    test "change_rest/1 returns a rest changeset" do
      rest = rest_fixture()
      assert %Ecto.Changeset{} = Zcms.change_rest(rest)
    end
  end
end
