defmodule ZcmsWeb.Schema do
  use Absinthe.Schema
  import Absinthe.Resolution.Helpers

  import_types(ZcmsWeb.Schema.{Types, Types.Custom.JSON, Types.Resume})

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
    field :resume, :resume do
      arg(:_id, non_null(:id))
      resolve(&Zcms.Generic.Resolver.find/2)
    end

    field :resumes, list_of(:resume) do
      arg(:_id, :id)
      arg(:awards, list_of(:input_awards))
      arg(:basics, :input_basics)
      arg(:education, list_of(:input_education))
      arg(:interests, list_of(:input_interests))
      arg(:languages, list_of(:input_languages))
      arg(:publications, list_of(:input_publications))
      arg(:references, list_of(:input_references))
      arg(:skills, list_of(:input_skills))
      arg(:volunteer, list_of(:input_volunteer))
      arg(:work, list_of(:input_work))

      resolve(&Zcms.Generic.Resolver.all/2)
    end

    mutation do
      field :create_resume, type: :resume do
        arg(:awards, list_of(:input_awards))
        arg(:basics, :input_basics)
        arg(:education, list_of(:input_education))
        arg(:interests, list_of(:input_interests))
        arg(:languages, list_of(:input_languages))
        arg(:publications, list_of(:input_publications))
        arg(:references, list_of(:input_references))
        arg(:skills, list_of(:input_skills))
        arg(:volunteer, list_of(:input_volunteer))
        arg(:work, list_of(:input_work))

        resolve(&Zcms.Generic.Resolver.create/2)
      end

      field :update_resume, type: :resume do
        arg(:_id, non_null(:id))
        arg(:awards, list_of(:input_awards))
        arg(:basics, :input_basics)
        arg(:education, list_of(:input_education))
        arg(:interests, list_of(:input_interests))
        arg(:languages, list_of(:input_languages))
        arg(:publications, list_of(:input_publications))
        arg(:references, list_of(:input_references))
        arg(:skills, list_of(:input_skills))
        arg(:volunteer, list_of(:input_volunteer))
        arg(:work, list_of(:input_work))
        resolve(&Zcms.Generic.Resolver.update/2)
      end

      field :delete_resume, type: :resume do
        arg(:_id, non_null(:id))
        resolve(&Zcms.Generic.Resolver.delete/2)
      end
    end
  end
end
