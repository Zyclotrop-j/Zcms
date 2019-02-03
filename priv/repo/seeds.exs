# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Zcms.Repo.insert!(%Zcms.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Zcms.Repo

{:ok, conn} = Mongo.start_link(url: "mongodb://localhost:27017/Test")

filename = "schema"

ijson =
  File.read!(Path.join(:code.priv_dir(:cms), "#{filename}.json"))
  |> Poison.decode!()

json =
  ijson
  |> Map.put("_$schema", ijson["$schema"])
  |> Map.put("_$id", ijson["$id"])
  |> Map.update!("title", fn i -> Regex.replace(~r/ /, i, "") |> String.downcase() end)
  |> Map.drop(["$schema", "$id"])

case Mongo.count_documents(conn, "schema", %{"title" => json["title"]}) do
  {:ok, 1} -> :ok
  other -> Mongo.insert_one!(conn, "schema", json)
end

IO.puts("Initialized DB")

# Zcms.Application.Transformer.transformSchema(fn a, b ->
#  Mongo.find(conn, a, b)
# end)
