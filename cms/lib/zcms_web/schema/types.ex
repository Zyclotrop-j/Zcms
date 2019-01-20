defmodule ZcmsWeb.Schema.Types do
  use Absinthe.Schema.Notation
  use Absinthe.Ecto, repo: Zcms.Repo

  import Absinthe.Resolution.Helpers
  import Zcms.Loaders.Mongo

  object :accounts_user do
    field(:_id, :id)
    field(:name, :string)
    field(:email, :string)

    field(:address, :address)

    field(:posts, list_of(:blog_post), resolve: loadMany(:zmongo, :user)) do
      arg(:_id, :id)
      arg(:title, :string)
      arg(:body, :string)
    end
  end

  object :address do
    field(:_id, :id)
    field(:street, :string)
    field(:city, :string)
    field(:country, :string)
  end

  object :blog_post do
    field(:_id, :id)
    field(:title, :string)
    field(:body, :string)

    field(:user, :accounts_user, resolve: loadOne(:zmongo)) do
      arg(:_id, :string)
      arg(:email, :string)
      arg(:name, :string)
      arg(:address, :input_address)
    end

    field(:tags, list_of(:string))
  end

  input_object :input_address do
    field(:_id, :id)
    field(:street, :string)
    field(:city, :string)
    field(:country, :string)
    field(:secadd, :input_address)
  end

  input_object :update_post_params do
    field(:title, :string)
    field(:body, :string)
    field(:accounts_user_id, :id)
  end
end
