defmodule ZcmsWeb.CaptchaControllerTest do
  use ZcmsWeb.ConnCase

  alias Zcms.Api
  alias Zcms.Api.Captcha

  @create_attrs %{apikey_crypt: "some apikey_crypt", apikey_hash: "some apikey_hash", captchaversion_crypt: "some captchaversion_crypt", mode: "some mode", response_crypt: "some response_crypt", secret_crypt: "some secret_crypt", user_crypt: "some user_crypt"}
  @update_attrs %{apikey_crypt: "some updated apikey_crypt", apikey_hash: "some updated apikey_hash", captchaversion_crypt: "some updated captchaversion_crypt", mode: "some updated mode", response_crypt: "some updated response_crypt", secret_crypt: "some updated secret_crypt", user_crypt: "some updated user_crypt"}
  @invalid_attrs %{apikey_crypt: nil, apikey_hash: nil, captchaversion_crypt: nil, mode: nil, response_crypt: nil, secret_crypt: nil, user_crypt: nil}

  def fixture(:captcha) do
    {:ok, captcha} = Api.create_captcha(@create_attrs)
    captcha
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all captchas", %{conn: conn} do
      conn = get conn, captcha_path(conn, :index)
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create captcha" do
    test "renders captcha when data is valid", %{conn: conn} do
      conn = post conn, captcha_path(conn, :create), captcha: @create_attrs
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get conn, captcha_path(conn, :show, id)
      assert json_response(conn, 200)["data"] == %{
        "id" => id,
        "apikey_crypt" => "some apikey_crypt",
        "apikey_hash" => "some apikey_hash",
        "captchaversion_crypt" => "some captchaversion_crypt",
        "mode" => "some mode",
        "response_crypt" => "some response_crypt",
        "secret_crypt" => "some secret_crypt",
        "user_crypt" => "some user_crypt"}
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, captcha_path(conn, :create), captcha: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update captcha" do
    setup [:create_captcha]

    test "renders captcha when data is valid", %{conn: conn, captcha: %Captcha{id: id} = captcha} do
      conn = put conn, captcha_path(conn, :update, captcha), captcha: @update_attrs
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get conn, captcha_path(conn, :show, id)
      assert json_response(conn, 200)["data"] == %{
        "id" => id,
        "apikey_crypt" => "some updated apikey_crypt",
        "apikey_hash" => "some updated apikey_hash",
        "captchaversion_crypt" => "some updated captchaversion_crypt",
        "mode" => "some updated mode",
        "response_crypt" => "some updated response_crypt",
        "secret_crypt" => "some updated secret_crypt",
        "user_crypt" => "some updated user_crypt"}
    end

    test "renders errors when data is invalid", %{conn: conn, captcha: captcha} do
      conn = put conn, captcha_path(conn, :update, captcha), captcha: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete captcha" do
    setup [:create_captcha]

    test "deletes chosen captcha", %{conn: conn, captcha: captcha} do
      conn = delete conn, captcha_path(conn, :delete, captcha)
      assert response(conn, 204)
      assert_error_sent 404, fn ->
        get conn, captcha_path(conn, :show, captcha)
      end
    end
  end

  defp create_captcha(_) do
    captcha = fixture(:captcha)
    {:ok, captcha: captcha}
  end
end
