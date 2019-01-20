defmodule ZcmsWeb.RestControllerTest do
  use ZcmsWeb.ConnCase

  alias Zcms.Zcms
  alias Zcms.Zcms.Rest

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  def fixture(:rest) do
    {:ok, rest} = Zcms.create_rest(@create_attrs)
    rest
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all resources", %{conn: conn} do
      conn = get conn, rest_path(conn, :index)
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create rest" do
    test "renders rest when data is valid", %{conn: conn} do
      conn = post conn, rest_path(conn, :create), rest: @create_attrs
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get conn, rest_path(conn, :show, id)
      assert json_response(conn, 200)["data"] == %{
        "id" => id}
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, rest_path(conn, :create), rest: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update rest" do
    setup [:create_rest]

    test "renders rest when data is valid", %{conn: conn, rest: %Rest{id: id} = rest} do
      conn = put conn, rest_path(conn, :update, rest), rest: @update_attrs
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get conn, rest_path(conn, :show, id)
      assert json_response(conn, 200)["data"] == %{
        "id" => id}
    end

    test "renders errors when data is invalid", %{conn: conn, rest: rest} do
      conn = put conn, rest_path(conn, :update, rest), rest: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete rest" do
    setup [:create_rest]

    test "deletes chosen rest", %{conn: conn, rest: rest} do
      conn = delete conn, rest_path(conn, :delete, rest)
      assert response(conn, 204)
      assert_error_sent 404, fn ->
        get conn, rest_path(conn, :show, rest)
      end
    end
  end

  defp create_rest(_) do
    rest = fixture(:rest)
    {:ok, rest: rest}
  end
end
