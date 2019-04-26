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
    SUB=#{sub}
    LIBCLUSTER_KUBERNETES_NODE_BASENAME=#{System.get_env("LIBCLUSTER_KUBERNETES_NODE_BASENAME")}
    LIBCLUSTER_KUBERNETES_SELECTOR=#{System.get_env("LIBCLUSTER_KUBERNETES_SELECTOR")}
    AUTH0_DOMAIN=#{System.get_env("AUTH0_DOMAIN")}
    CORS_ORIGINS=#{System.get_env("CORS_ORIGINS")}
    DB_HOSTNAME=#{System.get_env("DB_HOSTNAME")}
    MONGO_HOST=#{System.get_env("MONGO_HOST")}
    MONGODB_NAME=#{System.get_env("MONGODB_NAME")}
    AWS_S3_BUCKET=#{System.get_env("AWS_S3_BUCKET")}
    HEROKU_APP_ID=#{System.get_env("HEROKU_APP_ID")}
    HEROKU_APP_NAME=#{System.get_env("HEROKU_APP_NAME")}
    HEROKU_DYNO_ID=#{System.get_env("HEROKU_DYNO_ID")}
    HEROKU_RELEASE_CREATED_AT=#{System.get_env("HEROKU_RELEASE_CREATED_AT")}
    HEROKU_RELEASE_VERSION=#{System.get_env("HEROKU_RELEASE_VERSION")}
    HEROKU_SLUG_COMMIT=#{System.get_env("HEROKU_SLUG_COMMIT")}
    HEROKU_SLUG_DESCRIPTION=#{System.get_env("HEROKU_SLUG_DESCRIPTION")}
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

        {"/api/v1/#{x}",
         %{
           "get" => %{
             "security" => [
               %{"bearerAuth" => []}
             ],
             "summary" => "Index all #{x}",
             "responses" => %{
               "200" => %{
                 "description" => "Successfully got all #{x}s",
                 "content" => %{
                   "application/json" => %{
                     "schema" => %{
                       "type" => "array",
                       "items" => %{
                         "$ref" =>
                           "https://#{System.get_env("HEROKU_APP_NAME")}.herokuapp.com/api/schema/#{
                             schemaid
                           }#/data"
                       }
                     }
                   }
                 }
               }
             }
           },
           "post" => %{
             "security" => [
               %{"bearerAuth" => []}
             ],
             "summary" => "Create a new #{x}",
             "requestBody" => %{
               "required" => true,
               "content" => %{
                 "application/json" => %{
                   "schema" => %{
                     "$ref" =>
                       "https://#{System.get_env("HEROKU_APP_NAME")}.herokuapp.com/api/schema/#{
                         schemaid
                       }#/data"
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
                       "$ref" =>
                         "https://#{System.get_env("HEROKU_APP_NAME")}.herokuapp.com/api/schema/#{
                           schemaid
                         }#/data"
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

        {"/api/v1/#{x}/{id}",
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
             "security" => [
               %{"bearerAuth" => []}
             ],
             "summary" => "Get one specific #{x} identifed by url-param id",
             "responses" => %{
               "200" => %{
                 "description" => "Got #{x} identified by 'id'",
                 "content" => %{
                   "application/json" => %{
                     "schema" => %{
                       "$ref" =>
                         "https://#{System.get_env("HEROKU_APP_NAME")}.herokuapp.com/api/schema/#{
                           schemaid
                         }#/data"
                     }
                   }
                 }
               }
             }
           },
           "put" => %{
             "security" => [
               %{"bearerAuth" => []}
             ],
             "summary" => "Overwrite a #{x} with a new #{x}",
             "requestBody" => %{
               "required" => true,
               "content" => %{
                 "application/json" => %{
                   "schema" => %{
                     "$ref" =>
                       "https://#{System.get_env("HEROKU_APP_NAME")}.herokuapp.com/api/schema/#{
                         schemaid
                       }#/data"
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
                       "$ref" =>
                         "https://#{System.get_env("HEROKU_APP_NAME")}.herokuapp.com/api/schema/#{
                           schemaid
                         }#/data"
                     }
                   }
                 }
               }
             }
           },
           "patch" => %{
             "security" => [
               %{"bearerAuth" => []}
             ],
             "summary" => "Merge existing #{x} with the one provided in the body",
             "requestBody" => %{
               "required" => true,
               "content" => %{
                 "application/json" => %{
                   "schema" => %{
                     "$ref" =>
                       "https://#{System.get_env("HEROKU_APP_NAME")}.herokuapp.com/api/schema/#{
                         schemaid
                       }#/data"
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
                       "$ref" =>
                         "https://#{System.get_env("HEROKU_APP_NAME")}.herokuapp.com/api/schema/#{
                           schemaid
                         }#/data"
                     }
                   }
                 }
               }
             }
           },
           "delete" => %{
             "security" => [
               %{"bearerAuth" => []}
             ],
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
      "/assets/upload/{key}" => %{
        "security" => [
          %{"bearerAuth" => []}
        ],
        "parameters" => [
          %{
            "name" => "key",
            "in" => "path",
            "required" => true,
            "description" => "Assets's key",
            "schema" => %{
              "type" => "string",
              "format" => "uuid",
              "pattern" => "^[a-fA-F\d]{24}$"
            }
          }
        ],
        "get" => %{
          "summary" =>
            "Returns a signed url for the given key - asset is available under that given url",
          "responses" => %{
            "200" => %{
              "description" => "Returns list of all assets which belong to the logged in user",
              "content" => %{
                "application/json" => %{
                  "schema" => %{
                    "type" => "string",
                    "description" => "url of asset"
                  }
                }
              }
            }
          }
        },
        "delete" => %{
          "summary" => "Deletes the assets which is identified by key",
          "responses" => %{
            "201" => %{
              "description" => "Assets was successfully deleted from bucket"
            }
          }
        }
      },
      "/assets/upload" => %{
        "security" => [
          %{"bearerAuth" => []}
        ],
        "post" => %{
          "summary" => "Uploads an asset",
          "responses" => %{
            "200" => %{
              "description" => "Asset successfully added to bucket.",
              "content" => %{
                "application/json" => %{
                  "schema" => %{
                    "type" => "object",
                    "properties" => %{
                      "filename" => %{
                        "type" => "string",
                        "description" => "the name of the file (uuid)"
                      },
                      "url" => %{"type" => "string", "description" => "url to access it"}
                    }
                  }
                }
              }
            }
          }
        },
        "get" => %{
          "summary" => "List all assets",
          "responses" => %{
            "200" => %{
              "description" => "Returns list of all assets which belong to the logged in user",
              "content" => %{
                "application/json" => %{
                  "schema" => %{
                    "type" => "object",
                    "properties" => %{
                      "e_tag" => %{"type" => "string", "description" => "unique identifier"},
                      "key" => %{
                        "type" => "string",
                        "description" => "the name of the file (uuid)"
                      },
                      "last_modified" => %{
                        "type" => "string",
                        "description" => "ISO-date of last modification"
                      },
                      "size" => %{"type" => "string", "description" => "size in byte"},
                      "url" => %{"type" => "string", "description" => "url to the object"}
                    }
                  }
                }
              }
            }
          }
        }
      },
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
          "security" => [
            %{"bearerAuth" => []}
          ],
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
      "/graphiql" => %{
        "get" => %{
          "security" => [
            %{"bearerAuth" => []}
          ],
          "summary" => "GQL Api Demo",
          "responses" => %{
            "200" => %{
              "description" => "GQL Api demo HTML-based page",
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
      "/swaggerui" => %{
        "get" => %{
          "summary" => "Api Demo",
          "responses" => %{
            "200" => %{
              "description" => "Api demo HTML-based page",
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
        %{"url" => "https://#{System.get_env("HEROKU_APP_NAME")}.herokuapp.com/"}
      ],
      "components" => %{
        "securitySchemes" => %{
          "bearerAuth" => %{
            "type" => "http",
            "scheme" => "bearer",
            "bearerFormat" => "JWT"
          }
        }
      },
      "paths" => apidefs |> Map.merge(otherpaths) |> Map.merge(apidefsinner)
    }

    prettify =
      conn.query_string
      |> URI.decode_query()
      |> Map.get("pretty", false)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(:ok, s |> Poison.encode!(pretty: prettify))
  end
end
