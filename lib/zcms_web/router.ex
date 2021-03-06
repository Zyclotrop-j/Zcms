defmodule ZcmsWeb.AuthMockplug do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _opts) do
    sub =
      case get_req_header(conn, "x-mock-sub") do
        [mock] -> mock
        _ -> "DEFAUTL-MOCK-SUB"
      end

    assign(conn, :joken_claims, %{"sub" => sub})
  end
end

defmodule ZcmsWeb.Clientplug do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _opts) do
    client =
      case get_req_header(conn, "x-client") do
        [client] -> client
        _ -> nil
      end

    assign(conn, :filters, %{"client" => client})
  end
end

defmodule ZcmsWeb.Router do
  import Joken, except: [verify: 1]
  use ZcmsWeb, :router

  @skip_token_verification %{joken_skip: true}

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :assets do
    plug(:accepts, [:multipart])
  end

  pipeline :graphql do
    plug(ZcmsWeb.GQLContext)
  end

  pipeline :auth do
    if Application.get_env(:zcms, :environment) == :prod do
      plug(ZcmsWeb.JokenPlug,
        verify: &ZcmsWeb.Router.verify_function/1,
        on_error: &ZcmsWeb.Router.autherror_function/2
      )
    else
      plug(ZcmsWeb.AuthMockplug)
    end

    plug(ZcmsWeb.Clientplug)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :jsonhtml do
    plug(:accepts, ["json", "html"])
  end

  def autherror_function(conn, message) do
    raise ZcmsWeb.Unauthenticated,
      message: "You need an access token",
      detail: %{message: message, loginurl: System.get_env("AUTH0_DOMAIN")},
      conn: conn
  end

  def verify_function(conn) do
    a = "-----BEGIN CERTIFICATE-----"
    z = "-----END CERTIFICATE-----"

    ["Bearer " <> bearer] = get_req_header(conn, "authorization")

    {:ok, claims} =
      bearer
      |> String.split(".")
      |> hd
      |> Base.decode64!()
      |> Poison.decode()

    # # TODO:
    # get https://<myAuth0>.eu.auth0.com/.well-known/openid-configuration
    # -> jwks_uri
    # -> AUTH0_AUD
    # issuer -> AUTH0_ISS

    # ttl = 10 hours
    {:ok, keylist} =
      ZcmsWeb.SimpleCache.get(HTTPoison, :get!, [System.get_env("jwks")], ttl: 3600).body
      |> Poison.decode()

    matchingKey =
      Enum.find(keylist["keys"], fn x ->
        x["kid"] == claims["kid"] && x["alg"] == claims["alg"]
      end)

    key = hd(matchingKey["x5c"])

    parts =
      key
      |> Stream.unfold(&String.split_at(&1, 64))
      |> Enum.take_while(&(&1 != ""))

    fkey = a <> "\n" <> Enum.join(parts, "\n") <> "\n" <> z <> "\n"
    q = JOSE.JWK.from_pem(fkey)

    IO.puts(System.get_env("AUTH0_AUD"))
    IO.puts(System.get_env("AUTH0_ISS"))

    %Joken.Token{}
    |> with_json_module(Poison)
    |> with_signer(rs256(q))
    |> with_validation(
      "aud",
      &(&1 == System.get_env("AUTH0_AUD") || Enum.member?(&1, System.get_env("AUTH0_AUD")))
    )
    |> with_validation("exp", &(&1 > current_time))
    |> with_validation("iat", &(&1 <= current_time))
    |> with_validation("iss", &(&1 == System.get_env("AUTH0_ISS")))
  end

  scope "/", ZcmsWeb do
    # Use the default browser stack
    pipe_through(:browser)

    get("/", PageController, :index)
    get("/login", PageController, :login)
    get("/swaggerui", PageController, :swaggerui)
    get("/graphiql", PageController, :graphiql)
    get("/edit", PageController, :edit)
    get("/control/api", ControlController, :apiendpoints)
  end

  scope "/assets", ZcmsWeb do
    pipe_through([:assets, :auth])

    get("/upload", UploadController, :index)
    get("/upload/:id", UploadController, :show)
    post("/upload", UploadController, :create)
    delete("/upload/:id", UploadController, :delete)
  end

  # Other scopes may use custom stacks.
  scope "/api/v1", ZcmsWeb do
    # , :auth
    pipe_through([:api, :auth])
    get("/:resource", RestController, :index)
    get("/:resource/:id", RestController, :show)
    post("/:resource", RestController, :create)
    put("/:resource/:id", RestController, :replace)
    # match could be used for UPDATE-Verb, but that doesn't parse the body
    post("/:resource/:id", RestController, :update)
    patch("/:resource/:id", RestController, :patch)
    delete("/:resource/:id", RestController, :delete)
  end

  scope "/apig" do
    pipe_through([:api, :auth, :graphql])
    forward("/graphql", Absinthe.Plug, schema: ZcmsWeb.Schema)
    forward("/graphiql", Absinthe.Plug.GraphiQL, schema: ZcmsWeb.Schema)
  end

  scope "/control", ZcmsWeb do
    pipe_through([:jsonhtml, :auth])
    get("/meta", ControlController, :meta)
    get("/recompile", ControlController, :index)
  end
end
