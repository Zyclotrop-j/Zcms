defmodule ZcmsWeb.UploadController do
  use ZcmsWeb, :controller

  def index(%{assigns: %{joken_claims: %{"sub" => sub}}} = conn, _params) do
    # list_buckets()
    # , prefix: "default"
    stream =
      ExAws.S3.list_objects("assets-de",
        encoding_type: "url",
        prefix: Base.url_encode64(sub, padding: false)
      )
      |> ExAws.stream!(region: "eu-central-1")
      |> Stream.reject(fn x -> x.size == "0" end)
      |> Stream.map(&Map.take(&1, [:last_modified, :key, :e_tag, :size]))
      |> Stream.map(fn x -> Map.put(x, :url, Zcms.Resource.Asset.url(x.key)) end)
      |> Stream.map(fn x ->
        Map.update(x, :key, "", fn x -> x |> String.split("/") |> List.last() end)
      end)
      |> Stream.map(&Poison.encode!/1)
      |> Stream.intersperse(",")
      |> Stream.concat(["]"])

    # IO.inspect(stream)
    ["["]
    |> Stream.concat(stream)
    |> Enum.into(
      conn
      |> put_resp_content_type("application/json")
      |> put_resp_header("content-disposition", "attachment; filename=assets.json")
      |> send_chunked(200)
    )
  end

  def index(conn, _params), do: conn |> send_resp(401, "")

  def show(%{assigns: %{joken_claims: %{"sub" => sub}}} = conn, params) do
    response =
      Zcms.Resource.Asset.url("#{Base.url_encode64(sub, padding: false)}/#{params["id"]}",
        signed: true
      )

    conn
    |> put_resp_content_type("application/json")
    |> text(response |> Poison.encode!())
  end

  def show(conn, _params), do: conn |> send_resp(401, "")

  def create(%{assigns: %{joken_claims: %{"sub" => sub}}} = conn, %{
        "file" => %Plug.Upload{:path => path}
      }) do
    %{assigns: %{joken_claims: %{"sub" => sub}}} = conn

    file_uuid = UUID.uuid4(:hex)
    unique_filename = "#{file_uuid}"

    # x-amz-meta-

    {:ok, file} =
      Zcms.Resource.Asset.store(
        {%Plug.Upload{filename: unique_filename, path: path},
         Base.url_encode64(sub, padding: false)}
      )

    conn
    |> put_resp_content_type("application/json")
    |> text(
      %{
        :url =>
          Zcms.Resource.Asset.url("#{Base.url_encode64(sub, padding: false)}/#{unique_filename}"),
        :filename => unique_filename
      }
      |> Poison.encode!()
    )
  end

  def create(conn, _params), do: conn |> send_resp(401, "")

  def delete(%{assigns: %{joken_claims: %{"sub" => sub}}} = conn, params) do
    %{assigns: %{joken_claims: %{"sub" => sub}}} = conn

    :ok = Zcms.Resource.Asset.delete("#{Base.url_encode64(sub, padding: false)}/#{params["id"]}")

    conn
    |> send_resp(201, "")
  end

  def delete(conn, _params), do: conn |> send_resp(401, "")
end
