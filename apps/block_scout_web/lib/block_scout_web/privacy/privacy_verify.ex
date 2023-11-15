defmodule BlockScoutWeb.Privacy.PrivacyVerify do
  alias Explorer.Chain
  use BlockScoutWeb, :controller

  require Logger

  import HTTPoison
  import Jason

  plug(
    Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    length: 20_000_000,
    query_string_length: 1_000_000,
    pass: ["*/*"],
    json_decoder: Poison
  )

  def wallet_verify(conn, address) do
    if conn == nil do
      false
    else
      authorization_token = conn.req_cookies["authorization_token"]
      authorization_wallet = conn.req_cookies["authorization_wallet"]

      if authorization_token == nil || authorization_wallet == nil do
        false
      else
        payload = %{
          owner: authorization_wallet,
          address_verified: address,
          token: "As " <> authorization_token
        }

        headers = %{"Content-Type" => "application/json"}

        case HTTPoison.post(
               "http://localhost:8080/as-authorization/wallet-verified",
               Jason.encode!(payload),
               headers
             ) do
          {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
            case Jason.decode(body) do
              {:ok, %{"data" => data}} ->
                %{"status" => status} = data

                if status == true do
                  true
                else
                  false
                end

              {:error, e} ->
                false
            end

          {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
            false

          {:error, e} ->
            false
        end
      end
    end
  end

  def wallet_login_verify(conn) do
    if conn == nil do
      nil
    else
      authorization_token = conn.req_cookies["authorization_token"]
      authorization_wallet = conn.req_cookies["authorization_wallet"]

      if authorization_token == nil || authorization_wallet == nil do
        nil
      else
        payload = %{wallet_address: authorization_wallet, token: "As " <> authorization_token}
        headers = %{"Content-Type" => "application/json"}

        case HTTPoison.post(
               "http://localhost:8080/as-authorization/token-verified",
               Jason.encode!(payload),
               headers
             ) do
          {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
            case Jason.decode(body) do
              {:ok, %{"data" => data}} ->
                %{"wallet_address" => wallet_address} = data
                wallet_address

              {:error, e} ->
                nil
            end

          {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
            nil

          {:error, e} ->
            nil
        end
      end
    end
  end

  def log_verify(data, first_topic, second_topic, third_topic, fourth_topic, address_verify) do
    if address_verify == nil do
      false
    else
      topic_verify(first_topic, address_verify) || topic_verify(second_topic, address_verify) ||
        topic_verify(third_topic, address_verify) || topic_verify(fourth_topic, address_verify) ||
        verify_log_data(data, address_verify)
    end
  end

  def verify_log_data(data_string, verify_address) do
    address_modified = modify_hex_string(verify_address)
    data_modified = modify_hex_string(data_string)

    if address_modified == nil || data_modified == nil do
      false
    else
      String.downcase(data_modified) =~ String.downcase(address_modified)
    end
  end

  def topic_verify(topic, address) do
    address_modified = modify_hex_string(address)
    topic_modified = modify_hex_string(topic)

    topic_include =
      if topic_modified == nil || address_modified == nil do
        false
      else
        String.downcase(topic_modified) =~ String.downcase(address_modified)
      end

    topic_include
  end

  def modify_hex_string(hex) do
    if hex == nil do
      nil
    else
      modified_string = String.replace(hex, "0x", "")
      modified_string
    end
  end

end
