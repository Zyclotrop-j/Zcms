defmodule ZcmsWeb.RestController do
  use ZcmsWeb, :controller

  alias Zcms.Resource.Rest

  action_fallback(ZcmsWeb.FallbackController)

  def action(conn, _) do
    args = [conn, conn.params |> Map.delete("resource"), String.downcase(conn.params["resource"])]
    apply(__MODULE__, action_name(conn), args)
  end

  def index(conn, _params, ttype) do
    rests =
      Rest.list_rests(conn, ttype)
      |> Enum.to_list()

    render(conn, "index.json", rests: rests)
  end

  defp schemaloader(conn) do
    fn schema ->
      Rest.get_rest(
        conn,
        "schema",
        %{"title" => schema},
        fn rest ->
          {:ok,
           rest |> Map.update!("_id", &BSON.ObjectId.encode!/1) |> ExJsonSchema.Schema.resolve()}
        end,
        fn _, _, _ ->
          {:error, :not_found}
        end
      )
    end
  end

  def loadAndConvertJsonSchema(schema, conn) do
    {:ok, result} = ZcmsWeb.SchemaCache.get(schema, schemaloader(conn), ttl: 36000)
  end

  defp validate(schema, params) do
    case ExJsonSchema.Validator.validate(schema, params) do
      :ok ->
        :ok

      {:error, listoferrors} ->
        %{
          :type => :json_schema_error,
          :message => listoferrors |> Enum.map(fn {a, b} -> "#{a} at \"#{b}\"" end)
        }
    end
  end

  defp randomPizza() do
    "#{Faker.Pizza.size()}- #{Faker.Pizza.sauce()}-#{Faker.Pizza.meat()}-#{
      Faker.Pizza.toppings(3) |> Enum.join("-")
    }-#{Faker.Pizza.vegetable()}-#{Faker.Pizza.cheese()}-#{Faker.Pizza.combo()}_flavored-#{
      Faker.Pizza.style()
    }_style"
    |> String.replace(" ", "_")
  end

  defp checkContentType(conn) do
    case Enum.member?(conn |> get_req_header("content-type"), "application/json") do
      true -> :ok
      _ -> {:error, "Wrong content type"}
    end
  end

  def create(conn, rest_params, ttype) do
    {:ok, schema} = loadAndConvertJsonSchema(ttype, conn)
    :ok = validate(schema, rest_params)
    :ok = checkContentType(conn)

    IO.puts("create")
    IO.inspect(rest_params)

    with {:ok, %{} = rest} <-
           Rest.create_rest(
             conn,
             ttype,
             rest_params |> Map.update("title", randomPizza(), &String.downcase/1),
             fn rest -> {:ok, rest} end
           ) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        ZcmsWeb.Router.Helpers.rest_path(conn, :show, ttype, BSON.ObjectId.encode!(rest))
      )
      |> render("show.json", rest: Rest.get_rest(conn, ttype, %{"_id" => rest}))
    end
  end

  defp getTypeQueryFromRegEx(regex, ttype, id) do
    [_, type, by] = Regex.run(regex, ttype)
    [type, %{by => id}]
  end

  def show(conn, %{"id" => id}, ttype) do
    regex = ~r/(.+)by(.+)/
    regex2 = ~r/(.+)_by_(.+)/

    [type, query] =
      cond do
        Regex.match?(regex, ttype) ->
          getTypeQueryFromRegEx(regex, ttype, id)

        Regex.match?(regex2, ttype) ->
          getTypeQueryFromRegEx(regex2, ttype, id)

        true ->
          [ttype, %{"_id" => BSON.ObjectId.decode!(id)}]
      end

    {:ok, %{} = rest} =
      Rest.get_rest(
        conn,
        type,
        query,
        fn rest -> {:ok, rest} end,
        fn _, _, _ ->
          {:error, :not_found}
        end
      )

    render(conn, "show.json", rest: rest)
  end

  def update(conn, %{"id" => id} = rest_params, ttype) do
    :ok = checkContentType(conn)

    with {:ok, %{} = rest} <-
           Rest.update_rest(
             conn,
             ttype,
             id,
             rest_params |> Map.delete("id") |> Map.delete("title"),
             fn _ ->
               {:ok, Rest.get_rest(conn, ttype, %{"_id" => BSON.ObjectId.decode!(id)})}
             end
           ) do
      render(conn, "show.json", rest: rest)
    end
  end

  def patch(conn, %{"id" => id} = rest_params, ttype) do
    :ok = checkContentType(conn)

    with {:ok, %{} = rest} <-
           Rest.patch_rest(
             conn,
             ttype,
             id,
             rest_params |> Map.delete("id") |> Map.delete("title"),
             fn _ ->
               {:ok, Rest.get_rest(conn, ttype, %{"_id" => BSON.ObjectId.decode!(id)})}
             end
           ) do
      render(conn, "show.json", rest: rest)
    end
  end

  def replace(conn, %{"id" => id} = rest_params, ttype) do
    :ok = checkContentType(conn)

    with {:ok, %{} = rest} <-
           Rest.replace_rest(
             conn,
             ttype,
             id,
             rest_params |> Map.delete("id") |> Map.delete("title"),
             fn _ ->
               {:ok, Rest.get_rest(conn, ttype, %{"_id" => BSON.ObjectId.decode!(id)})}
             end
           ) do
      render(conn, "show.json", rest: rest)
    end
  end

  def delete(conn, %{"id" => id}, ttype) do
    with {:ok, %{}} <- Rest.delete_rest(conn, ttype, id, fn _ -> {:ok, %{}} end) do
      send_resp(conn, :no_content, "")
    end
  end
end
