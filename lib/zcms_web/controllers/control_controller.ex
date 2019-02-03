defmodule ZcmsWeb.ControlController do
  use ZcmsWeb, :controller

  @version Mix.Project.config()[:version]
  def version(), do: @version

  def index(conn, _params) do
    :ok =
      Zcms.Application.Transformer.transformSchema(fn a, b ->
        Mongo.find(:mongo, a, b, pool: DBConnection.Poolboy)
      end)

    send_resp(conn, :no_content, "")
  end

  def meta(conn, _params) do
    sub =
      conn.assigns
      |> Map.get(:joken_claims)
      |> Map.get("sub")

    settings = """
    Signed in as "#{sub}"

    LIBCLUSTER_KUBERNETES_NODE_BASENAME=#{System.get_env("LIBCLUSTER_KUBERNETES_NODE_BASENAME")}
    LIBCLUSTER_KUBERNETES_SELECTOR=#{System.get_env("LIBCLUSTER_KUBERNETES_SELECTOR")}
    AUTH0_DOMAIN=#{System.get_env("AUTH0_DOMAIN")}
    CORS_ORIGINS=#{System.get_env("CORS_ORIGINS")}
    DB_HOSTNAME=#{System.get_env("DB_HOSTNAME")}
    MONGO_HOST=#{System.get_env("MONGO_HOST")}
    jwks=#{System.get_env("jwks")}
    version=#{version}
    """

    send_resp(conn, :ok, settings)
  end

  def apiendpoints(conn, _params) do
    r =
      Mongo.command!(:mongo, %{:listCollections => 1, :nameOnly => True},
        pool: DBConnection.Poolboy
      )

    IO.inspect(r)

    # wait for mongoDB elixir to be update -> gotta have own listCollections command!
    r =
      r["cursor"]["firstBatch"]
      |> Stream.filter(fn coll -> coll["type"] == "collection" end)
      |> Stream.map(fn coll -> coll["name"] end)
      |> Enum.to_list()

    IO.inspect(r)
    # |> Enum.map(fn i -> i["name"] end)
    # |> Poison.encode!()

    "control/meta"
    "apig/graphql"
    "api"
    "login"
    send_resp(conn, :ok, r)
  end
end
