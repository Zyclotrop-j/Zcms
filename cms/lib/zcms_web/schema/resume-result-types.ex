defmodule ZcmsWeb.Schema.Types.Resume do
  use Absinthe.Schema.Notation
  use Absinthe.Ecto, repo: Zcms.Repo

  import Absinthe.Resolution.Helpers
  import Zcms.Loaders.Mongo

  object :resume do
    field(:_id, :id)
    field(:awards, list_of(:awards))
    field(:basics, :basics)
    field(:education, list_of(:education))
    field(:interests, list_of(:interests))
    field(:languages, list_of(:languages))
    field(:publications, list_of(:publications))
    field(:references, list_of(:references))
    field(:skills, list_of(:skills))
    field(:volunteer, list_of(:volunteer))
    field(:work, list_of(:work))
    field(:more, :json)
  end

  object :awards do
    field(:_id, :id)
    field(:awarder, :string)
    field(:date, :string)
    field(:summary, :string)
    field(:title, :string)
  end

  object :basics do
    field(:_id, :id)
    field(:email, :string)
    field(:label, :string)
    field(:location, :location)
    field(:name, :string)
    field(:phone, :string)
    field(:picture, :string)
    field(:profiles, list_of(:profiles))
    field(:summary, :string)
    field(:url, :string)
  end

  object :location do
    field(:_id, :id)
    field(:address, :string)
    field(:city, :string)
    field(:country_code, :string)
    field(:postal_code, :string)
    field(:region, :string)
  end

  object :profiles do
    field(:_id, :id)
    field(:network, :string)
    field(:url, :string)
    field(:username, :string)
  end

  object :education do
    field(:_id, :id)
    field(:area, :string)
    field(:courses, list_of(:string))
    field(:end_date, :string)
    field(:gpa, :string)
    field(:institution, :string)
    field(:start_date, :string)
    field(:study_type, :string)
  end

  object :interests do
    field(:_id, :id)
    field(:keywords, list_of(:string))
    field(:name, :string)
  end

  object :languages do
    field(:_id, :id)
    field(:level, :string)
    field(:name, :string)
  end

  object :publications do
    field(:_id, :id)
    field(:name, :string)
    field(:publisher, :string)
    field(:release_date, :string)
    field(:summary, :string)
    field(:url, :string)
  end

  object :references do
    field(:_id, :id)
    field(:name, :string)
    field(:reference, :string)
  end

  object :skills do
    field(:_id, :id)
    field(:keywords, list_of(:string))
    field(:level, :string)
    field(:name, :string)
  end

  object :volunteer do
    field(:_id, :id)
    field(:end_date, :string)
    field(:highlights, list_of(:string))
    field(:organization, :string)
    field(:position, :string)
    field(:start_date, :string)
    field(:summary, :string)
    field(:url, :string)
  end

  object :work do
    field(:_id, :id)
    field(:company, :string)
    field(:end_date, :string)
    field(:highlights, list_of(:string))
    field(:position, :string)
    field(:start_date, :string)
    field(:summary, :string)
    field(:url, :string)
  end

  input_object :input_awards do
    field(:_id, :id)
    field(:awarder, :string)
    field(:date, :string)
    field(:summary, :string)
    field(:title, :string)
  end

  input_object :input_basics do
    field(:_id, :id)
    field(:email, :string)
    field(:label, :string)
    field(:location, :input_location)
    field(:name, :string)
    field(:phone, :string)
    field(:picture, :string)
    field(:profiles, list_of(:input_profiles))
    field(:summary, :string)
    field(:url, :string)
  end

  input_object :input_location do
    field(:_id, :id)
    field(:address, :string)
    field(:city, :string)
    field(:country_code, :string)
    field(:postal_code, :string)
    field(:region, :string)
  end

  input_object :input_profiles do
    field(:_id, :id)
    field(:network, :string)
    field(:url, :string)
    field(:username, :string)
  end

  input_object :input_education do
    field(:_id, :id)
    field(:area, :string)
    field(:courses, list_of(:string))
    field(:end_date, :string)
    field(:gpa, :string)
    field(:institution, :string)
    field(:start_date, :string)
    field(:study_type, :string)
  end

  input_object :input_interests do
    field(:_id, :id)
    field(:keywords, list_of(:string))
    field(:name, :string)
  end

  input_object :input_languages do
    field(:_id, :id)
    field(:level, :string)
    field(:name, :string)
  end

  input_object :input_publications do
    field(:_id, :id)
    field(:name, :string)
    field(:publisher, :string)
    field(:release_date, :string)
    field(:summary, :string)
    field(:url, :string)
  end

  input_object :input_references do
    field(:_id, :id)
    field(:name, :string)
    field(:reference, :string)
  end

  input_object :input_skills do
    field(:_id, :id)
    field(:keywords, list_of(:string))
    field(:level, :string)
    field(:name, :string)
  end

  input_object :input_volunteer do
    field(:_id, :id)
    field(:end_date, :string)
    field(:highlights, list_of(:string))
    field(:organization, :string)
    field(:position, :string)
    field(:start_date, :string)
    field(:summary, :string)
    field(:url, :string)
  end

  input_object :input_work do
    field(:_id, :id)
    field(:company, :string)
    field(:end_date, :string)
    field(:highlights, list_of(:string))
    field(:position, :string)
    field(:start_date, :string)
    field(:summary, :string)
    field(:url, :string)
  end
end
