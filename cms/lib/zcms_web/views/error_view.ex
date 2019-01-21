defmodule ZcmsWeb.ErrorView do
  use ZcmsWeb, :view

  def render("401.html", _assigns) do
    "Not allowed"
  end

  def render("404.html", _assigns) do
    "Page not found"
  end

  def render("500.html", _assigns) do
    "Internal server error"
  end

  def render("201.json", _assigns) do
    %{
      errors: %{
        message: Map.get(_assigns, :message) || "Nothing to do",
        detail: Map.get(_assigns, :detail) || nil
      }
    }
  end

  def render("400.json", _assigns) do
    %{
      errors: %{
        message: Map.get(_assigns, :message) || "Malformed request",
        detail: Map.get(_assigns, :detail) || nil
      }
    }
  end

  def render("400.html", %{reason: %Plug.Parsers.ParseError{} = r}) do
    "Invalid JSON: '" <> r.exception.message <> "'"
  end

  def render("401.json", _assigns) do
    %{
      errors: %{
        message: Map.get(_assigns, :message) || "Authentication required",
        detail: Map.get(_assigns, :detail) || nil
      }
    }
  end

  def render("403.json", _assigns) do
    %{
      errors: %{
        message: Map.get(_assigns, :message) || "Unauthorized",
        detail: Map.get(_assigns, :detail) || nil
      }
    }
  end

  def render("404.json", _assigns) do
    %{
      errors: %{
        message: Map.get(_assigns, :message) || "Page not found",
        detail: Map.get(_assigns, :detail) || nil
      }
    }
  end

  def render("500.json", _assigns) do
    %{
      errors: %{
        message: Map.get(_assigns, :message) || "Internal server error",
        detail: Map.get(_assigns, :detail) || nil
      }
    }
  end

  def render("501.json", _assigns) do
    %{
      errors: %{
        message: Map.get(_assigns, :message) || "Authentication required",
        detail: Map.get(_assigns, :detail) || nil
      }
    }
  end

  # In case no render clause matches or no
  # template is found, let's render it as 500
  def template_not_found(_template, assigns) do
    render("500.html", assigns)
  end
end
