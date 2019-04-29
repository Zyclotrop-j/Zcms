defmodule Zcms.Resource.Rest do
  def map_keys(map, fun) do
    case map do
      %BSON.ObjectId{} ->
        map

      %{} ->
        for {key, val} <- map,
            into: %{},
            do: {fun.(key), map_keys(val, fun)}

      [_ | _] ->
        Enum.map(map, fn item -> map_keys(item, fun) end)

      val ->
        val
    end
  end

  @moduledoc """
  The Zcms context.
  """

  @doc """
  Returns the list of rests.

  ## Examples

      iex> list_rests()
      [%Rest{}, ...]

  """
  # TODO: HANDLE $ in key by rewrite -> $ not supported in GQL
  def list_rests(read_only_conn, type, query \\ %{}, r \\ & &1, e \\ & &1) do
    permquery = buildpermissionquery(read_only_conn, "show")

    r.(
      Mongo.find(:mongo, type, query |> DeepMerge.deep_merge(permquery),
        pool: DBConnection.Poolboy
      )
      |> Enum.map(fn i -> map_keys(i, fn i -> Regex.replace(~r/^_dlr_/, i, "$") end) end)
      |> Enum.map(&humanizeFileTimes/1)
      |> Enum.map(fn x -> addMeta(x, type) end)
    )
  end

  defp addMeta(obj, type),
    do:
      obj
      |> Map.put("_links", %{
        "base" => "https://#{System.get_env("HEROKU_APP_NAME")}.herokuapp.com/api/v1/",
        "links" => [
          %{
            "rel" => "self",
            "href" => type <> "/" <> "#{obj["_id"]}"
          },
          %{
            "rel" => "describedby",
            "href" => "schemaByTitle/" <> type
          }
        ]
      })
      |> Map.put("x-type", "#{type}")
      |> Map.put("x-id", "#{obj["_id"]}")

  defp addNewPermissionSet(obj, read_only_conn, type, _, schema \\ nil) do
    sub = read_only_conn.assigns.joken_claims["sub"]

    baseSchema =
      case schema do
        nil ->
          get_rest(
            read_only_conn,
            "schema",
            %{"title" => type}
          )

        _ ->
          schema
      end

    lgin = baseSchema["_permissions"]["state:loggedin"]
    pub = baseSchema["_permissions"]["state:public"]

    groups =
      baseSchema["_permissions"]
      |> Map.to_list()
      |> Enum.filter(fn {key, val} -> key |> String.starts_with?("group:") end)
      |> Map.new()

    obj
    |> Map.put(
      "_permissions",
      %{
        "__owner__" => sub,
        # TODO: Version 2.0.0 - Group feature
        "group:#{sub}" => %{
          "show" => false,
          "create" => false,
          "replace" => false,
          "update" => false,
          "delete" => false,
          "grant" => true
        },
        "state:loggedin" => lgin,
        "state:public" => pub
      }
      |> Map.merge(groups)
    )
    |> Map.put("_lastModifiedBy", sub)
    |> Map.put("_author", sub)
  end

  defp buildpermissionquery(%{assigns: %{joken_claims: %{"sub" => sub}}}, action)
       when sub != nil and action in ["create", "replace", "update", "delete"] do
    %{
      "$or" => [
        %{"_permissions.__owner__" => sub},
        %{"_permissions.state:loggedin.#{action}" => true},
        %{"_permissions.#{sub}.#{action}" => true}
      ]
    }
  end

  defp buildpermissionquery(%{assigns: %{joken_claims: %{"sub" => sub}}}, action)
       when sub != nil and action in ["grant"] do
    %{
      "$or" => [
        %{"_permissions.__owner__" => sub},
        %{"_permissions.#{sub}.#{action}" => true}
      ]
    }
  end

  defp buildpermissionquery(%{assigns: %{joken_claims: %{"sub" => sub}}}, action)
       when sub != nil and action in ["show"] do
    %{
      "$or" => [
        %{"_permissions.__owner__" => sub},

        # Update implies read as update returns the object
        %{"_permissions.state:public.update" => true},
        %{"_permissions.state:loggedin.update" => true},
        %{"_permissions.#{sub}.update" => true, "_draft" => false},

        # Replace implies read as replace returns the object
        %{"_permissions.state:public.replace" => true},
        %{"_permissions.state:loggedin.replace" => true},
        %{"_permissions.#{sub}.replace" => true, "_draft" => false},

        # Standard show action
        %{"_permissions.state:public.#{action}" => true},
        %{"_permissions.state:loggedin.#{action}" => true},
        %{"_permissions.#{sub}.#{action}" => true, "_draft" => false}
      ]
    }
  end

  defp buildpermissionquery(_, action)
       when action in ["show"] do
    %{
      "$or" => [
        %{"_permissions.state:public.#{action}" => true, "_draft" => false}
      ]
    }
  end

  defp stripOwner(query),
    do:
      query
      |> Map.update("_permissions", %{}, &Map.delete(&1, "__owner__"))
      |> Map.delete("_author")
      |> Map.delete("_lastModifiedBy")

  defp isPermissionsUpdated?(%{"_permissions" => map}) when map != %{}, do: true
  defp isPermissionsUpdated?(_), do: false

  defp updateFileTimes(obj, mod \\ false, cre \\ false) do
    now = System.system_time(:second)

    [
      {"_created", cre},
      {"_modified", mod}
    ]
    |> Enum.reduce(obj, fn {field, modi}, acc ->
      if modi, do: renewFileTime(acc, field, now), else: dropFileTime(acc, field)
    end)
  end

  defp dropFileTime(obj, field), do: obj |> Map.delete(field)
  defp renewFileTime(obj, field, now), do: obj |> Map.put(field, now)

  defp humanizeFileTimes(obj),
    do:
      obj
      |> humanizeFileTime("_created")
      |> humanizeFileTime("_modified")

  defp humanizeFileTime(obj, field) do
    obj
    |> Map.update(field, 0, fn backThen ->
      backThen |> DateTime.from_unix!() |> DateTime.to_iso8601()
    end)
  end

  # TODO:
  defp addVersionInfo do
    # For Version 2.0.0 - Versioning
    # version-history
    # latest-version
  end

  # TODO:
  defp addMonitorInfo do
    # For Version 2.0.0 - Watching via subscriptions (web-socket)
    # monitor
    # monitor-group
  end

  # TODO:
  defp addCursorInfo do
    # For Version 2.0.0 - Cursor
    # first, last, next, prev
  end

  @doc """
  Gets a single rest.

  Raises if the Rest does not exist.

  ## Examples

      iex> get_rest!(123)
      %Rest{}

  """
  def get_rest(
        read_only_conn,
        type,
        query,
        r \\ & &1,
        e \\ fn _, _, _ -> {:error, "Not found"} end
      ) do
    permquery = buildpermissionquery(read_only_conn, "show")

    case Mongo.find_one(:mongo, type, query |> DeepMerge.deep_merge(permquery),
           pool: DBConnection.Poolboy
         ) do
      nil ->
        e.(type, query, nil)

      item ->
        r.(
          item
          # |> stripPermissionsIfNotHasGrand(read_only_conn) # # TODO: For V 2.0.0 - strip permissions to own permissions unless grant
          |> humanizeFileTimes()
          |> addMeta(type)
          |> map_keys(fn i -> Regex.replace(~r/^_dlr_/, i, "$") end)
        )
    end
  end

  defp createError(type, _, {:error, %Mongo.Error{:message => message, :code => code}}),
    do: {:error, "Couldn't insert new #{type}; (MongoDB Error #{code}): #{message}"}

  defp createError(type, _, _),
    do: {:error, "Couldn't insert new #{type}"}

  defp addDraft(argsmap), do: argsmap |> Map.update("_draft", true, & &1)

  @doc """
  Creates a rest.

  ## Examples

      iex> create_rest(%{field: value})
      {:ok, %Rest{}}

      iex> create_rest(%{field: bad_value})
      {:error, ...}

  """
  def create_rest(
        read_only_conn,
        type,
        argsmap,
        r \\ & &1,
        e \\ &createError/3
      ) do
    permquery = buildpermissionquery(read_only_conn, "create")

    IO.puts("create_rest")
    IO.inspect(argsmap)

    case get_rest(
           read_only_conn,
           "schema",
           %{"title" => type} |> Map.merge(permquery)
         ) do
      nil ->
        e.(type, argsmap, "Not allowed! (403)")

      item ->
        case Mongo.insert_one(
               :mongo,
               type,
               addNewPermissionSet(%{}, read_only_conn, type, argsmap, item)
               # Exclude owner field. All other privilages are do overwrite
               |> DeepMerge.deep_merge(argsmap |> stripOwner() |> addDraft())
               # Filetimes server-side only
               |> updateFileTimes(true, true)
               |> map_keys(fn i -> Regex.replace(~r/^\$/, i, "_dlr_") end),
               pool: DBConnection.Poolboy
             ) do
          {:ok, %{:inserted_id => id}} ->
            if type == "schema" do
              :ok =
                Zcms.Application.Transformer.transformSchema(fn a, b ->
                  Mongo.find(:mongo, a, b, pool: DBConnection.Poolboy)
                end)
            end

            r.(id)

          er ->
            e.(type, argsmap, er)
        end
    end
  end

  defp updateError(type, id, _, %{:matched_count => 0, :modified_count => _}),
    do: {:error, "Couldn't find #{type} with _id=#{id}"}

  defp updateError(type, id, _, {:error, %Mongo.Error{:message => message, :code => code}}),
    do: {:error, "Couldn't update #{type} with _id=#{id}; (MongoDB Error #{code}): #{message}"}

  defp updateError(type, id, _, _), do: {:error, "Couldn't update #{type} with _id=#{id}"}

  defp addModifiedBy(obj, %{assigns: %{joken_claims: %{"sub" => sub}}}),
    do: obj |> Map.put("_lastModifiedBy", sub)

  @doc """
  Updates a rest.

  ## Examples

      iex> update_rest(rest, %{field: new_value})
      {:ok, %Rest{}}

      iex> update_rest(rest, %{field: bad_value})
      {:error, ...}

  """
  def update_rest(read_only_conn, type, id, map, r \\ & &1, e \\ &updateError/4) do
    permquery = buildpermissionquery(read_only_conn, "update")

    mapWithoutForbitten = map |> stripOwner()

    grantquery =
      if isPermissionsUpdated?(mapWithoutForbitten),
        do: buildpermissionquery(read_only_conn, "grant"),
        else: %{}

    case Mongo.update_one(
           :mongo,
           type,
           %{"_id" => BSON.ObjectId.decode!(id)}
           |> DeepMerge.deep_merge(permquery)
           |> DeepMerge.deep_merge(grantquery),
           %{
             "$set" =>
               mapWithoutForbitten
               |> addModifiedBy(read_only_conn)
               |> updateFileTimes(true)
               |> map_keys(fn i -> Regex.replace(~r/^\$/, i, "_dlr_") end)
               |> JSONPointer.dehydrate!()
               |> Enum.map(fn {key, val} ->
                 {Regex.replace(~r/\//, key, ".") |> String.to_charlist() |> tl() |> to_string(),
                  val}
               end)
               |> Enum.filter(fn {key, val} -> val != %{} end)
               |> Map.new()
           },
           pool: DBConnection.Poolboy
         ) do
      {:ok, %{:matched_count => 1, :modified_count => 1}} ->
        if type == "schema" do
          :ok =
            Zcms.Application.Transformer.transformSchema(fn a, b ->
              Mongo.find(:mongo, a, b, pool: DBConnection.Poolboy)
            end)
        end

        r.(id)

      {:ok, %{:matched_count => 1, :modified_count => 0}} ->
        r.(id)

      {:ok, a} ->
        e.(type, id, map, a)

      q ->
        e.(type, id, map, q)
    end
  end

  def replace_rest(read_only_conn, type, id, map, r \\ & &1, e \\ &updateError/4) do
    map = map |> Map.put_new("_id", id)

    if map["_id"] != id,
      do:
        raise(ZcmsWeb.InvalidRequest,
          message: "_id of old and new object must equal, found id=#{id} and _id=#{map["_id"]}"
        )

    if type == "schema" do
      %{"title" => title} =
        get_rest(read_only_conn, "schema", %{"_id" => BSON.ObjectId.decode!(id)})

      if title == "schema" do
        raise "Cannot replace root-schema. Every new schema created is validated against it!"
      end
    end

    mapWithoutForbitten = map |> stripOwner()
    permquery = buildpermissionquery(read_only_conn, "replace")

    grantquery =
      if isPermissionsUpdated?(mapWithoutForbitten),
        do: buildpermissionquery(read_only_conn, "grant"),
        else: %{}

    olddocument = get_rest(read_only_conn, type, %{"_id" => BSON.ObjectId.decode!(id)})

    baseobj =
      mapWithoutForbitten
      # Only update _permissions if they're not being overwritten already
      |> Map.put_new("_permissions", olddocument["_permissions"])
      |> Map.update(
        "_permissions",
        %{},
        &Map.put(&1, "__owner__", olddocument["_permissions"]["__owner__"])
      )
      |> updateFileTimes(true, true)
      # Re-add _author and _created
      |> Map.put("_author", olddocument["_author"])
      |> Map.put("_created", olddocument["_created"])
      |> addModifiedBy(read_only_conn)
      # (MongoDB Error 66): command failed: After applying the update, the (immutable) field '_id' was found to have been altered
      |> Map.delete("_id")

    case Mongo.find_one_and_replace(
           :mongo,
           type,
           %{"_id" => BSON.ObjectId.decode!(id)}
           |> DeepMerge.deep_merge(permquery)
           |> DeepMerge.deep_merge(grantquery),
           baseobj
           |> addModifiedBy(read_only_conn)
           |> updateFileTimes(true)
           |> map_keys(fn i -> Regex.replace(~r/^\$/, i, "_dlr_") end),
           pool: DBConnection.Poolboy
         ) do
      {:ok, _} ->
        if type == "schema" do
          :ok =
            Zcms.Application.Transformer.transformSchema(fn a, b ->
              Mongo.find(:mongo, a, b, pool: DBConnection.Poolboy)
            end)
        end

        r.(id)

      q ->
        e.(type, id, map, q)
    end
  end

  defp deleteError(type, id, %{:deleted_count => 0}),
    do: {:error, "Didn't find #{type} with _id=#{id}"}

  defp deleteError(type, id, _),
    do: {:error, "Something went wrong deleting #{type} with _id=#{id}"}

  @doc """
  Deletes a Rest.

  ## Examples

      iex> delete_rest(rest)
      {:ok, %Rest{}}

      iex> delete_rest(rest)
      {:error, ...}

  """
  def delete_rest(read_only_conn, type, id, r \\ & &1, e \\ &deleteError/3) do
    if type == "schema" do
      %{"title" => title} =
        get_rest(read_only_conn, "schema", %{"_id" => BSON.ObjectId.decode!(id)})

      if title == "schema" do
        raise "Cannot delete root-schema. Every new schema created is validated against it!"
      end

      ZcmsWeb.SchemaCache.clear(title)
      IO.puts("Cleared #{title} from caching table")
    end

    permquery = buildpermissionquery(read_only_conn, "delete")

    case Mongo.delete_one(
           :mongo,
           type,
           %{"_id" => BSON.ObjectId.decode!(id)} |> DeepMerge.deep_merge(permquery),
           pool: DBConnection.Poolboy
         ) do
      {:ok, %{:deleted_count => 1}} ->
        if type == "schema" do
          :ok =
            Zcms.Application.Transformer.transformSchema(fn a, b ->
              Mongo.find(:mongo, a, b, pool: DBConnection.Poolboy)
            end)
        end

        r.(nil)

      {:ok, a} ->
        e.(type, id, a)

      q ->
        e.(type, id, q)
    end
  end
end
