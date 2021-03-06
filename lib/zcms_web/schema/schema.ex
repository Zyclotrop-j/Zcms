defmodule ZcmsWeb.Schema do
  use Absinthe.Schema
  import Absinthe.Resolution.Helpers

  import_types(ZcmsWeb.Schema.{Types, Types.Custom.JSON})

  def context(ctx) do
    loader =
      Dataloader.new()
      |> Dataloader.add_source(:zmongo, Zcms.Loaders.Mongo.data())

    Map.put(ctx, :loader, loader)
  end

  def plugins do
    [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
  end

  query do
  end
end
