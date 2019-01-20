defmodule ZcmsWeb.CORS do
  use Corsica.Router,
    origins: ["http://localhost", ~r<^https://([a-zA-Z]+\.)#{System.get_env("CORS_ORIGINS")}$>, ~s<https://#{System.get_env("CORS_ORIGINS")}>],
    allow_credentials: true,
    max_age: 600,
    expose_headers: ~w(x-expires authorization location x-user),
    allow_headers: ~w(x-expires authorization location x-user)

  resource "/validate/*",
    origins: "*",
    allow_credentials: false,
    expose_headers: ~w(x-expires x-token x-captchastate),
    allow_headers: ~w(x-sitekey x-response x-token),
    allow_methods: :all
  resource "/*"
end
