defmodule ZcmsWeb.CORS do
  use Corsica.Router,
    origins: [
      "http://localhost",
      "http://localhost:4000",
      "http://localhost:8000",
      ~r<^https://([a-zA-Z]+\.)#{System.get_env("CORS_ORIGINS")}$>,
      ~s<https://#{System.get_env("CORS_ORIGINS")}>
    ],
    allow_credentials: true,
    max_age: 600,
    expose_headers: ~w(x-expires authorization location x-user content-type),
    allow_headers: ~w(x-expires authorization location x-user content-type),
    allow_methods: ["GET"]

  resource("/api/v1/*",
    origins: [
      "http://localhost",
      "http://localhost:4000",
      "http://localhost:8000",
      ~r<^https://([a-zA-Z]+\.)#{System.get_env("CORS_ORIGINS")}$>,
      ~s<https://#{System.get_env("CORS_ORIGINS")}>
    ],
    allow_credentials: true,
    max_age: 600,
    expose_headers:
      ~w(x-expires authorization location x-user content-type) ++
        if(Application.get_env(:zcms, :environment) == :prod, do: ["x-mock-sub"], else: []),
    allow_headers:
      ~w(x-expires authorization location x-user content-type) ++
        if(Application.get_env(:zcms, :environment) == :prod, do: ["x-mock-sub"], else: []),
    allow_methods: ["PUT", "PATCH", "DELETE", "POST", "GET", "OPTIONS"]
  )

  resource("/apig/*",
    origins: [
      "http://localhost",
      "http://localhost:4000",
      "http://localhost:8000",
      ~r<^https://([a-zA-Z]+\.)#{System.get_env("CORS_ORIGINS")}$>,
      ~s<https://#{System.get_env("CORS_ORIGINS")}>
    ],
    allow_credentials: true,
    max_age: 600,
    expose_headers:
      ~w(x-expires authorization location x-user content-type) ++
        if(Application.get_env(:zcms, :environment) == :prod, do: ["x-mock-sub"], else: []),
    allow_headers:
      ~w(x-expires authorization location x-user content-type) ++
        if(Application.get_env(:zcms, :environment) == :prod, do: ["x-mock-sub"], else: []),
    allow_methods: ["POST", "GET", "OPTIONS"]
  )

  resource("/*")
end
