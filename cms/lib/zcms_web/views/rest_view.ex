defmodule ZcmsWeb.RestView do
  use ZcmsWeb, :view
  alias ZcmsWeb.RestView

  def render("index.json", %{rests: rests}) do
    %{data: render_many(rests, RestView, "rest.json")}
  end

  def render("show.json", %{rest: rest}) do
    %{data: render_one(rest, RestView, "rest.json")}
  end

  def render("rest.json", %{rest: rest}) do
    rest
  end
end
