defmodule Zcms.Application do
  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    children = [
      # Start the Ecto repository
      supervisor(Zcms.Repo, []),
      # Start the endpoint when the application starts
      supervisor(ZcmsWeb.Endpoint, []),
      worker(Mongo, [[name: :mongo, database: "Test", pool: DBConnection.Poolboy]])
      # Start your own worker by calling: Zcms.Worker.start_link(arg1, arg2, arg3)
      # worker(Zcms.Worker, [arg1, arg2, arg3]),
    ]

    # Create in-memory-tables for caching
    :simple_cache = :ets.new(:simple_cache, [:set, :protected, :named_table])
    :my_app_user_routes = :ets.new(:my_app_user_routes, [:named_table, :bag, :public])

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Zcms.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    ZcmsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
