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

  def transaction_filter(transactions, wallet_filter) do
    if transactions == nil || wallet_filter == nil do
      []
    else
      transaction_list =
        Enum.map(transactions, fn transaction ->
          %Chain.Transaction{
            from_address_hash: from_address_hash,
            to_address_hash: to_address_hash
          } = transaction

          if wallet_filter == from_address_hash || wallet_filter == to_address_hash do
            transaction
          else
            transaction
          end
        end)
      transaction_list
    end
  end

  def token_transfer_filter(token_transfers, wallet_filter) do
    if token_transfers == nil || wallet_filter == nil do
      []
    else
      token_transfer_list =
        Enum.map(token_transfers, fn token_transfer ->
          %Chain.TokenTransfer{
            from_address_hash: from_address_hash,
            to_address_hash: to_address_hash
          } = token_transfer

          if wallet_filter == from_address_hash || wallet_filter == to_address_hash do
            token_transfer
          end
        end)

      token_transfer_list
    end
  end

  def internal_transaction_filter(internal_transactions, wallet_filter) do
    if internal_transactions == nil || wallet_filter == nil || length(internal_transactions) <= 0 do
      []
    else
      internal_transaction_list =
        Enum.map(internal_transactions, fn internal_transaction ->
          %Chain.InternalTransaction{
            from_address_hash: from_address_hash,
            to_address_hash: to_address_hash
          } = internal_transaction

          if wallet_filter == from_address_hash || wallet_filter == to_address_hash do
            internal_transaction
          else
            private_internal_transaction = %Chain.InternalTransaction{
              internal_transaction
              | # block_number: Explorer.Chain.Block.block_number() | nil,
                # type: Type.t(),
                # call_type: CallType.t() | nil,
                # created_contract_address: %Ecto.Association.NotLoaded{} | Address.t() | nil,
                # created_contract_address_hash: Hash.t() | nil,
                # created_contract_code: Data.t() | nil,
                # error: String.t(),
                # from_address: %Ecto.Association.NotLoaded{} | Address.t(),
                # from_address_hash: Hash.Address.t(),
                gas: nil,
                gas_used: nil,
                # index: non_neg_integer(),
                init: nil,
                input: nil,
                output: nil,
                # to_address: %Ecto.Association.NotLoaded{} | Address.t() | nil,
                # to_address_hash: Hash.Address.t() | nil,
                # trace_address: [non_neg_integer()],
                # transaction: %Ecto.Association.NotLoaded{} | Transaction.t(),
                # transaction_hash: Hash.t(),
                # transaction_index: Transaction.transaction_index() | nil,
                value: %Explorer.Chain.Wei{value: Decimal.new(0)}
                # block_hash: Hash.Full.t(),
                # block_index: non_neg_integer()
            }

            private_internal_transaction
          end
        end)

      internal_transaction_list
    end
  end
end
