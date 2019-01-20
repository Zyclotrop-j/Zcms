defmodule ZcmsWeb.RestController do
  use ZcmsWeb, :controller

  alias Zcms.Resource.Rest

  action_fallback(ZcmsWeb.FallbackController)

  def action(conn, _) do
    args = [conn, conn.params |> Map.delete("resource"), conn.params["resource"]]
    apply(__MODULE__, action_name(conn), args)
  end

  def index(conn, _params, ttype) do
    rests =
      Rest.list_rests(ttype)
      |> Enum.to_list()

    render(conn, "index.json", rests: rests)
  end

  def create(conn, rest_params, ttype) do
    with {:ok, %{} = rest} <- Rest.create_rest(ttype, rest_params, fn rest -> {:ok, rest} end) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        ZcmsWeb.Router.Helpers.rest_path(conn, :show, ttype, BSON.ObjectId.encode!(rest))
      )
      |> render("show.json", rest: Rest.get_rest(ttype, %{"_id" => rest}))
    end
  end

  def show(conn, %{"id" => id}, ttype) do
    {:ok, %{} = rest} =
      Rest.get_rest(
        ttype,
        %{"_id" => BSON.ObjectId.decode!(id)},
        fn rest -> {:ok, rest} end,
        fn _, _, _ ->
          {:error, :not_found}
        end
      )

    render(conn, "show.json", rest: rest)
  end

  def update(conn, %{"id" => id} = rest_params, ttype) do
    with {:ok, %{} = rest} <-
           Rest.update_rest(ttype, id, rest_params |> Map.delete("id"), fn _ ->
             {:ok, Rest.get_rest(ttype, %{"_id" => BSON.ObjectId.decode!(id)})}
           end) do
      render(conn, "show.json", rest: rest)
    end
  end

  def delete(conn, %{"id" => id}, ttype) do
    with {:ok, %{}} <- Rest.delete_rest(ttype, id, fn _ -> {:ok, %{}} end) do
      send_resp(conn, :no_content, "")
    end
  end
end
