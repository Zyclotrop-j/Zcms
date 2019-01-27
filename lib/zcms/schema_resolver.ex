defmodule Zcms.Application.SchemaResolver do
  def resolver(url) do
    %{
      "type" => "object",
      "required" => ["$id", "$ref"],
      "properties" => %{
        "$id" => %{"type" => "string"},
        "$ref": %{"type" => "string"},
        "$db": %{"type" => "string"}
      }
    }
  end
end
