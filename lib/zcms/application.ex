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
      worker(Mongo, [
        Application.get_env(:zcms, Zcms.Resource.Rest)
      ])
      # Start your own worker by calling: Zcms.Worker.start_link(arg1, arg2, arg3)
      # worker(Zcms.Worker, [arg1, arg2, arg3]),
    ]

    # Create in-memory-tables for caching
    :simple_cache = :ets.new(:simple_cache, [:set, :public, :named_table])
    :schema_cache = :ets.new(:schema_cache, [:set, :public, :named_table])

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Zcms.Supervisor]
    x = Supervisor.start_link(children, opts)

    IO.puts("Setup DB.....")

    Zcms.Application.Transformer.initMetaDB(
      fn a, b ->
        Mongo.count_documents(:mongo, a, b, pool: DBConnection.Poolboy)
      end,
      fn a, b ->
        Mongo.insert_one!(:mongo, a, b, pool: DBConnection.Poolboy)
      end,
      fn a ->
        Mongo.command!(:mongo, a, pool: DBConnection.Poolboy)
      end
    )

    IO.puts("....Initialized DB with meta schema")

    :ok =
      Zcms.Application.Transformer.transformSchema(fn a, b ->
        Mongo.find(:mongo, a, b, pool: DBConnection.Poolboy)
      end)

    IO.puts("....Initializing from DB done")
    x
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    ZcmsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
