defmodule ZcmsWeb.CORS do
  use Corsica.Router,
    origins: [
      "http://localhost",
      ~r<^https://([a-zA-Z]+\.)#{System.get_env("CORS_ORIGINS")}$>,
      ~s<https://#{System.get_env("CORS_ORIGINS")}>
    ],
    allow_credentials: true,
    max_age: 600,
    expose_headers: ~w(x-expires authorization location x-user),
    allow_headers: ~w(x-expires authorization location x-user),
    allow_methods: ["GET"]

  resource("/api/v1/*",
    origins: [
      "http://localhost",
      ~r<^https://([a-zA-Z]+\.)#{System.get_env("CORS_ORIGINS")}$>,
      ~s<https://#{System.get_env("CORS_ORIGINS")}>
    ],
    allow_credentials: true,
    max_age: 600,
    expose_headers:
      ~w(x-expires authorization location x-user) ++
        if(Application.get_env(:myapp, :environment) == :prod, do: ["x-mock-sub"], else: []),
    allow_headers:
      ~w(x-expires authorization location x-user) ++
        if(Application.get_env(:myapp, :environment) == :prod, do: ["x-mock-sub"], else: []),
    allow_methods: ["PUT", "PATCH", "DELETE", "POST", "GET", "OPTIONS"]
  )

  resource("/apig/*",
    origins: [
      "http://localhost",
      ~r<^https://([a-zA-Z]+\.)#{System.get_env("CORS_ORIGINS")}$>,
      ~s<https://#{System.get_env("CORS_ORIGINS")}>
    ],
    allow_credentials: true,
    max_age: 600,
    expose_headers:
      ~w(x-expires authorization location x-user) ++
        if(Application.get_env(:myapp, :environment) == :prod, do: ["x-mock-sub"], else: []),
    allow_headers:
      ~w(x-expires authorization location x-user) ++
        if(Application.get_env(:myapp, :environment) == :prod, do: ["x-mock-sub"], else: []),
    allow_methods: ["POST", "GET", "OPTIONS"]
  )

  resource("/*")
end
