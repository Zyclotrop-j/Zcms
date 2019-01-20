defmodule Zcms.ApiTest do
  use Zcms.DataCase

  alias Zcms.Api

  describe "captchas" do
    alias Zcms.Api.Captcha

    @valid_attrs %{apikey_crypt: "some apikey_crypt", apikey_hash: "some apikey_hash", captchaversion_crypt: "some captchaversion_crypt", mode: "some mode", response_crypt: "some response_crypt", secret_crypt: "some secret_crypt", user_crypt: "some user_crypt"}
    @update_attrs %{apikey_crypt: "some updated apikey_crypt", apikey_hash: "some updated apikey_hash", captchaversion_crypt: "some updated captchaversion_crypt", mode: "some updated mode", response_crypt: "some updated response_crypt", secret_crypt: "some updated secret_crypt", user_crypt: "some updated user_crypt"}
    @invalid_attrs %{apikey_crypt: nil, apikey_hash: nil, captchaversion_crypt: nil, mode: nil, response_crypt: nil, secret_crypt: nil, user_crypt: nil}

    def captcha_fixture(attrs \\ %{}) do
      {:ok, captcha} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Api.create_captcha()

      captcha
    end

    test "list_captchas/0 returns all captchas" do
      captcha = captcha_fixture()
      assert Api.list_captchas() == [captcha]
    end

    test "get_captcha!/1 returns the captcha with given id" do
      captcha = captcha_fixture()
      assert Api.get_captcha!(captcha.id) == captcha
    end

    test "create_captcha/1 with valid data creates a captcha" do
      assert {:ok, %Captcha{} = captcha} = Api.create_captcha(@valid_attrs)
      assert captcha.apikey_crypt == "some apikey_crypt"
      assert captcha.apikey_hash == "some apikey_hash"
      assert captcha.captchaversion_crypt == "some captchaversion_crypt"
      assert captcha.mode == "some mode"
      assert captcha.response_crypt == "some response_crypt"
      assert captcha.secret_crypt == "some secret_crypt"
      assert captcha.user_crypt == "some user_crypt"
    end

    test "create_captcha/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Api.create_captcha(@invalid_attrs)
    end

    test "update_captcha/2 with valid data updates the captcha" do
      captcha = captcha_fixture()
      assert {:ok, captcha} = Api.update_captcha(captcha, @update_attrs)
      assert %Captcha{} = captcha
      assert captcha.apikey_crypt == "some updated apikey_crypt"
      assert captcha.apikey_hash == "some updated apikey_hash"
      assert captcha.captchaversion_crypt == "some updated captchaversion_crypt"
      assert captcha.mode == "some updated mode"
      assert captcha.response_crypt == "some updated response_crypt"
      assert captcha.secret_crypt == "some updated secret_crypt"
      assert captcha.user_crypt == "some updated user_crypt"
    end

    test "update_captcha/2 with invalid data returns error changeset" do
      captcha = captcha_fixture()
      assert {:error, %Ecto.Changeset{}} = Api.update_captcha(captcha, @invalid_attrs)
      assert captcha == Api.get_captcha!(captcha.id)
    end

    test "delete_captcha/1 deletes the captcha" do
      captcha = captcha_fixture()
      assert {:ok, %Captcha{}} = Api.delete_captcha(captcha)
      assert_raise Ecto.NoResultsError, fn -> Api.get_captcha!(captcha.id) end
    end

    test "change_captcha/1 returns a captcha changeset" do
      captcha = captcha_fixture()
      assert %Ecto.Changeset{} = Api.change_captcha(captcha)
    end
  end
end
