defmodule ZcmsWeb.ControlController do
  use ZcmsWeb, :controller

  @version Mix.Project.config()[:version]
  def version(), do: @version

  @title Mix.Project.config()[:app]
  def app(), do: @app

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
    app=#{Atom.to_string(app)}
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

    IO.inspect(r)

    # wait for mongoDB elixir to be update -> gotta have own listCollections command!
    r =
      r["cursor"]["firstBatch"]
      |> Stream.filter(fn coll -> coll["type"] == "collection" end)
      |> Stream.map(fn coll -> coll["name"] end)
      |> Enum.to_list()

    allschemas = Zcms.Resource.Rest.list_rests("schema")

    %{
      "openapi" => "3.0.0",
      "info" => %{
        "title" => Atom.to_string(app),
        "version" => version
      },
      "servers" => [
        %{"url" => "#{System.get_env(APP_NAME)}.gigalixirapp.com"}
      ],
      "paths" => %{
        "/control" => %{
          "/meta" => %{
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
          "/api" => %{
            "get" => %{
              "summary" => "Get the current api-spec",
              "responses" => %{
                "200" => %{
                  "description" => "The current context and environment",
                  "content" => %{
                    "application/json" => %{
                      "schema" => %{
                        # Apperantly they didn't publish the 3.0.0 not yet :(
                        "ref" => "http://swagger.io/v2/schema.json"
                      }
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
        },
        "api" =>
          r
          |> Map.new(fn x ->
            schemaid =
              allschemas
              |> Enum.find(fn x -> x["title"] == x end)["_id"]
              |> BSON.ObjectId.encode!()

            {"/#{x}",
             %{
               "get" => %{
                 "summary" => "Index all #{x}",
                 "responses" => %{
                   "200" => %{
                     "content" => %{
                       "application/json" => %{
                         "schema" => %{
                           "type" => "array",
                           "items" => %{
                             # # TODO: Add index and get on title
                             "ref" => "/app/schema/#{schemaid}"
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
                   "required" => True,
                   "content" => %{
                     "application/json" => %{
                       "schema" => %{
                         # # TODO: Add index and get on title
                         "ref" => "/app/schema/#{schemaid}"
                       }
                     }
                   }
                 },
                 "responses" => %{
                   "200" => %{
                     "content" => %{
                       "application/json" => %{
                         "schema" => %{
                           # # TODO: Add index and get on title
                           "ref" => "/app/schema/#{schemaid}"
                         }
                       }
                     }
                   }
                 }
               },
               "/{id}" => %{
                 "parameters" => [
                   %{
                     "name" => "id",
                     "in" => "path",
                     "required" => True,
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
                       "content" => %{
                         "application/json" => %{
                           "schema" => %{
                             # # TODO: Add index and get on title
                             "ref" => "/app/schema/#{schemaid}"
                           }
                         }
                       }
                     }
                   }
                 },
                 "put" => %{
                   "summary" => "Overwrite a #{x} with a new #{x}",
                   "requestBody" => %{
                     "required" => True,
                     "content" => %{
                       "application/json" => %{
                         "schema" => %{
                           # # TODO: Add index and get on title
                           "ref" => "/app/schema/#{schemaid}"
                         }
                       }
                     }
                   },
                   "responses" => %{
                     "200" => %{
                       "content" => %{
                         "application/json" => %{
                           "schema" => %{
                             # # TODO: Add index and get on title
                             "ref" => "/app/schema/#{schemaid}"
                           }
                         }
                       }
                     }
                   }
                 },
                 "patch" => %{
                   "summary" => "Merge existing #{x} with the one provided in the body",
                   "requestBody" => %{
                     "required" => True,
                     "content" => %{
                       "application/json" => %{
                         "schema" => %{
                           # # TODO: Add index and get on title
                           "ref" => "/app/schema/#{schemaid}"
                         }
                       }
                     }
                   },
                   "responses" => %{
                     "200" => %{
                       "content" => %{
                         "application/json" => %{
                           "schema" => %{
                             # # TODO: Add index and get on title
                             "ref" => "/app/schema/#{schemaid}"
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
               }
             }}
          end)
      }
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(:ok, r |> Poison.encode!())
  end
end
