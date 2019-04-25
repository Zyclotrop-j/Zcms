defmodule Zcms.Resource.Asset do
  use Arc.Definition

  @versions [:original]
  @acl :public_read
  @extension_whitelist ~w(.jpg .jpeg .gif .png .svg .webp)

  def validate({file, _}) do
    file_extension = file.file_name |> Path.extname() |> String.downcase()
    Enum.member?(@extension_whitelist, file_extension)
    true
  end

  def storage_dir(version, {file, scope} = debug) do
    pre = scope || ""

    file.file_name
    |> String.split("/")
    |> Enum.slice(0..-2)
    |> Enum.concat([pre])
    |> Enum.join("/")
  end
end
