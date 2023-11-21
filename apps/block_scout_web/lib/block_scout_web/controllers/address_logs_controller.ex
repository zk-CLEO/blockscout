defmodule BlockScoutWeb.AddressLogsController do
  @moduledoc """
  Manages events logs tab.
  """

  import BlockScoutWeb.Chain,
    only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.{AccessHelpers, AddressLogsView, Controller}
  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token
  alias Indexer.Fetcher.CoinBalanceOnDemand
  alias Phoenix.View
  alias BlockScoutWeb.Privacy.PrivacyVerify

  use BlockScoutWeb, :controller

  def index(conn, %{"address_id" => address_hash_string, "type" => "JSON"} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         :ok <- Chain.check_address_exists(address_hash),
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params) do
      ## Verify wallet
      address_verified = PrivacyVerify.wallet_verify(conn, address_hash_string)
      wallet_login = PrivacyVerify.wallet_login_verify(conn)

      wallet_login_hash =
        if wallet_login == nil do
          nil
        else
          {:ok, wallet_login_hash} = Chain.string_to_address_hash(wallet_login)
          wallet_login_hash
        end

      ##

      logs_plus_one = Chain.address_to_logs(address_hash, paging_options(params))
      {results, next_page} = split_list_by_page(logs_plus_one)

      next_page_url =
        case next_page_params(next_page, results, params) do
          nil ->
            nil

          next_page_params ->
            address_logs_path(conn, :index, address_hash, Map.delete(next_page_params, "type"))
        end

      items =
        results
        |> Enum.map(fn log ->
          %Chain.Log{
            data: data,
            first_topic: first_topic,
            second_topic: second_topic,
            third_topic: third_topic,
            fourth_topic: fourth_topic
          } = log

          if PrivacyVerify.log_verify(
               Chain.Data.to_string(data),
               first_topic,
               second_topic,
               third_topic,
               fourth_topic,
               wallet_login
             ) == true || address_verified == true do
            View.render_to_string(
              AddressLogsView,
              "_logs.html",
              log: log,
              conn: conn
            )
          else
            private_log = %Chain.Log{
              log
              | # address: %Ecto.Association.NotLoaded{} | Address.t(),
                # address_hash: Hash.Address.t(),
                # block_hash: Hash.Full.t(),
                block_number: nil,
                data: nil,
                # first_topic: String.t(),
                second_topic: "(PRIVATE DATA)",
                third_topic: "(PRIVATE DATA)",
                fourth_topic: "(PRIVATE DATA)",
                # transaction: %Ecto.Association.NotLoaded{} | Transaction.t(),
                # transaction_hash: Hash.Full.t(),
                # index: non_neg_integer(),
                type: nil
            }

            View.render_to_string(
              AddressLogsView,
              "_logs.html",
              log: private_log,
              conn: conn
            )
          end
        end)

      json(
        conn,
        %{
          items: items,
          next_page_path: next_page_url
        }
      )
    else
      _ ->
        not_found(conn)
    end
  end

  def index(conn, %{"address_id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash),
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params) do
      render(
        conn,
        "index.html",
        address: address,
        current_path: Controller.current_full_path(conn),
        coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        counters_path: address_path(conn, :address_counters, %{"id" => address_hash_string})
      )
    else
      _ ->
        not_found(conn)
    end
  end

  def search_logs(conn, %{"topic" => topic, "address_id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         :ok <- Chain.check_address_exists(address_hash) do
      ## Verify wallet
      address_verified = PrivacyVerify.wallet_verify(conn, address_hash_string)
      wallet_login = PrivacyVerify.wallet_login_verify(conn)

      wallet_login_hash =
        if wallet_login == nil do
          nil
        else
          {:ok, wallet_login_hash} = Chain.string_to_address_hash(wallet_login)
          wallet_login_hash
        end

      ##

      topic = String.trim(topic)

      formatted_topic = if String.starts_with?(topic, "0x"), do: topic, else: "0x" <> topic

      logs_plus_one = Chain.address_to_logs(address_hash, topic: formatted_topic)

      {results, next_page} = split_list_by_page(logs_plus_one)

      next_page_url =
        case next_page_params(next_page, results, params) do
          nil ->
            nil

          next_page_params ->
            address_logs_path(conn, :index, address_hash, Map.delete(next_page_params, "type"))
        end

      items =
        results
        |> Enum.map(fn log ->
          %Chain.Log{
            data: data,
            first_topic: first_topic,
            second_topic: second_topic,
            third_topic: third_topic,
            fourth_topic: fourth_topic
          } = log

          if PrivacyVerify.log_verify(
               Chain.Data.to_string(data),
               first_topic,
               second_topic,
               third_topic,
               fourth_topic,
               wallet_login
             ) == true || address_verified == true do
            View.render_to_string(
              AddressLogsView,
              "_logs.html",
              log: log,
              conn: conn
            )
          else
            private_log = %Chain.Log{
              log
              | # address: %Ecto.Association.NotLoaded{} | Address.t(),
                # address_hash: Hash.Address.t(),
                # block_hash: Hash.Full.t(),
                block_number: nil,
                data: nil,
                # first_topic: String.t(),
                second_topic: "(PRIVATE DATA)",
                third_topic: "(PRIVATE DATA)",
                fourth_topic: "(PRIVATE DATA)",
                # transaction: %Ecto.Association.NotLoaded{} | Transaction.t(),
                # transaction_hash: Hash.Full.t(),
                # index: non_neg_integer(),
                type: nil
            }

            View.render_to_string(
              AddressLogsView,
              "_logs.html",
              log: private_log,
              conn: conn
            )
          end
        end)

      json(
        conn,
        %{
          items: items,
          next_page_path: next_page_url
        }
      )
    else
      _ ->
        not_found(conn)
    end
  end

  def search_logs(conn, _), do: not_found(conn)
end
