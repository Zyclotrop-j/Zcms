defmodule ZcmsWeb.ControlController do
  use ZcmsWeb, :controller

  @version Mix.Project.config()[:version]
  def version(), do: @version

  @app Mix.Project.config()[:app]
  def appldesc(), do: @app

  def index(conn, _params) do
    :ok =
      Zcms.Application.Transformer.transformSchema(fn a, b ->
        Mongo.find(:mongo, a, b, pool: DBConnection.Poolboy)
      end)

    send_resp(conn, :no_content, "")
  end

  def meta(conn, _params) do
    sub =
      conn.assigns
      |> Map.get(:joken_claims)
      |> Map.get("sub")

    settings = """
    Signed in as "#{sub}"

    LIBCLUSTER_KUBERNETES_NODE_BASENAME=#{System.get_env("LIBCLUSTER_KUBERNETES_NODE_BASENAME")}
    LIBCLUSTER_KUBERNETES_SELECTOR=#{System.get_env("LIBCLUSTER_KUBERNETES_SELECTOR")}
    AUTH0_DOMAIN=#{System.get_env("AUTH0_DOMAIN")}
    CORS_ORIGINS=#{System.get_env("CORS_ORIGINS")}
    DB_HOSTNAME=#{System.get_env("DB_HOSTNAME")}
    MONGO_HOST=#{System.get_env("MONGO_HOST")}
    jwks=#{System.get_env("jwks")}
    version=#{version}
    app=#{Atom.to_string(appldesc)}
    """

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(:ok, settings)
  end

  def apiendpoints(conn, _params) do
    r =
      Mongo.command!(:mongo, %{:listCollections => 1, :nameOnly => True},
        pool: DBConnection.Poolboy
      )

    # wait for mongoDB elixir to be update -> gotta have own listCollections command!
    # see https://github.com/ankhers/mongodb/blame/79e0e4426562a6cabf5917f7b9eda41f14c5920b/lib/mongo.ex#L821
    r =
      r["cursor"]["firstBatch"]
      |> Stream.filter(fn coll -> coll["type"] == "collection" end)
      |> Stream.map(fn coll -> coll["name"] end)
      |> Enum.to_list()

    allschemas = Zcms.Resource.Rest.list_rests(conn, "schema")

    apidefs =
      r
      |> Enum.filter(fn rs ->
        Enum.any?(allschemas, fn schema -> schema["title"] == rs end)
      end)
      |> Map.new(fn x ->
        schemaid =
          BSON.ObjectId.encode!(
            Enum.find(allschemas, fn schema -> schema["title"] == x end)["_id"]
          )

        {"/api/#{x}",
         %{
           "get" => %{
             "summary" => "Index all #{x}",
             "responses" => %{
               "200" => %{
                 "description" => "Successfully got all #{x}s",
                 "content" => %{
                   "application/json" => %{
                     "schema" => %{
                       "type" => "array",
                       "items" => %{
                         # # TODO: Add index and get on title
                         "$ref" => "/app/schema/#{schemaid}"
                       }
                     }
                   }
                 }
               }
             }
           },
           "post" => %{
             "summary" => "Create a new #{x}",
             "requestBody" => %{
               "required" => true,
               "content" => %{
                 "application/json" => %{
                   "schema" => %{
                     # # TODO: Add index and get on title
                     "$ref" => "/app/schema/#{schemaid}"
                   }
                 }
               }
             },
             "responses" => %{
               "200" => %{
                 "description" => "Successfully created new #{x}",
                 "content" => %{
                   "application/json" => %{
                     "schema" => %{
                       # # TODO: Add index and get on title
                       "$ref" => "/app/schema/#{schemaid}"
                     }
                   }
                 }
               }
             }
           }
         }}
      end)

    apidefsinner =
      r
      |> Enum.filter(fn rs ->
        Enum.any?(allschemas, fn schema -> schema["title"] == rs end)
      end)
      |> Map.new(fn x ->
        schemaid =
          BSON.ObjectId.encode!(
            Enum.find(allschemas, fn schema -> schema["title"] == x end)["_id"]
          )

        {"/api/#{x}/{id}",
         %{
           "parameters" => [
             %{
               "name" => "id",
               "in" => "path",
               "required" => true,
               "description" => "Item id of the #{x}",
               "schema" => %{
                 "type" => "string",
                 "format" => "uuid",
                 "pattern" => "^[a-fA-F\d]{24}$"
               }
             }
           ],
           "get" => %{
             "summary" => "Get one specific #{x} identifed by url-param id",
             "responses" => %{
               "200" => %{
                 "description" => "Got #{x} identified by 'id'",
                 "content" => %{
                   "application/json" => %{
                     "schema" => %{
                       # # TODO: Add index and get on title
                       "$ref" => "/app/schema/#{schemaid}"
                     }
                   }
                 }
               }
             }
           },
           "put" => %{
             "summary" => "Overwrite a #{x} with a new #{x}",
             "requestBody" => %{
               "required" => true,
               "content" => %{
                 "application/json" => %{
                   "schema" => %{
                     # # TODO: Add index and get on title
                     "$ref" => "/app/schema/#{schemaid}"
                   }
                 }
               }
             },
             "responses" => %{
               "200" => %{
                 "description" => "Successfully overwrote #{x}",
                 "content" => %{
                   "application/json" => %{
                     "schema" => %{
                       # # TODO: Add index and get on title
                       "$ref" => "/app/schema/#{schemaid}"
                     }
                   }
                 }
               }
             }
           },
           "patch" => %{
             "summary" => "Merge existing #{x} with the one provided in the body",
             "requestBody" => %{
               "required" => true,
               "content" => %{
                 "application/json" => %{
                   "schema" => %{
                     # # TODO: Add index and get on title
                     "$ref" => "/app/schema/#{schemaid}"
                   }
                 }
               }
             },
             "responses" => %{
               "200" => %{
                 "description" => "Successfully patched #{x}",
                 "content" => %{
                   "application/json" => %{
                     "schema" => %{
                       # # TODO: Add index and get on title
                       "$ref" => "/app/schema/#{schemaid}"
                     }
                   }
                 }
               }
             }
           },
           "delete" => %{
             "summary" => "Delete an #{x}",
             "responses" => %{
               "201" => %{
                 "description" => "Successfully deleted #{x}",
                 "content" => %{
                   "application/json" => %{
                     "schema" => %{
                       "type" => "string"
                     }
                   }
                 }
               }
             }
           }
         }}
      end)

    otherpaths = %{
      "/control/meta" => %{
        "get" => %{
          "summary" => "Get the current context and environment",
          "responses" => %{
            "200" => %{
              "description" => "The current context and environment",
              "content" => %{
                "text/plain" => %{
                  "schema" => %{
                    "type" => "string"
                  }
                }
              }
            }
          }
        }
      },
      "/control/api" => %{
        "get" => %{
          "summary" => "Get the current api-spec",
          "responses" => %{
            "200" => %{
              "description" => "The current context and environment",
              "content" => %{
                "application/json" => %{
                  "schema" => %{
                    # Apperantly they didn't publish the 3.0.0 not yet :(
                    "$ref" => "http://swagger.io/v2/schema.json"
                  }
                }
              }
            }
          }
        }
      },
      "/apig/graphql" => %{
        "get" => %{
          "summary" => "GraphQL endpoint root",
          "responses" => %{
            "200" => %{
              "description" => "The current context and environment",
              "content" => %{
                "text/plain" => %{
                  "schema" => %{
                    # Ah..... skip?!
                    "type" => "string"
                  }
                }
              }
            }
          }
        }
      },
      "/login" => %{
        "get" => %{
          "summary" => "Login Demo",
          "responses" => %{
            "200" => %{
              "description" => "Login demo HTML-based page",
              "content" => %{
                "text/html" => %{
                  "schema" => %{
                    "type" => "string"
                  }
                }
              }
            }
          }
        }
      }
    }

    s = %{
      "openapi" => "3.0.0",
      "info" => %{
        "title" => Atom.to_string(appldesc),
        "version" => version
      },
      "servers" => [
        %{"url" => "https://#{System.get_env("APP_NAME")}.gigalixirapp.com/"}
      ],
      "paths" => otherpaths |> Map.merge(apidefsinner) |> Map.merge(apidefs)
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(:ok, s |> Poison.encode!(pretty: true))
  end
end
