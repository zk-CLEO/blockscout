defmodule BlockScoutWeb.TransactionLogController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.{AccessHelpers, Controller, TransactionController, TransactionLogView}
  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token
  alias Phoenix.View
  alias BlockScoutWeb.Privacy.PrivacyVerify

  def index(conn, %{"transaction_id" => transaction_hash_string, "type" => "JSON"} = params) do
    with {:ok, transaction_hash} <- Chain.string_to_transaction_hash(transaction_hash_string),
         {:ok, transaction} <-
           Chain.hash_to_transaction(transaction_hash,
             necessity_by_association: %{[to_address: :smart_contract] => :optional}
           ),
         {:ok, false} <-
           AccessHelpers.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <-
           AccessHelpers.restricted_access?(to_string(transaction.to_address_hash), params) do
      ## Verify wallet
      address_verified = PrivacyVerify.wallet_verify(conn, nil)
      wallet_login = PrivacyVerify.wallet_login_verify(conn)

      wallet_login_hash =
        if wallet_login == nil do
          nil
        else
          {:ok, wallet_login_hash} = Chain.string_to_address_hash(wallet_login)
          wallet_login_hash
        end

      ##
      full_options =
        Keyword.merge(
          [
            necessity_by_association: %{
              address: :optional
            }
          ],
          paging_options(params)
        )

      logs_plus_one = Chain.transaction_to_logs(transaction_hash, full_options)

      {logs, next_page} = split_list_by_page(logs_plus_one)

      next_page_url =
        case next_page_params(next_page, logs, params) do
          nil ->
            nil

          next_page_params ->
            transaction_log_path(conn, :index, transaction, Map.delete(next_page_params, "type"))
        end

      items =
        logs
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
              TransactionLogView,
              "_logs.html",
              log: log,
              conn: conn,
              transaction: transaction
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
                second_topic: "Private",
                third_topic: "Private",
                fourth_topic: "Private",
                # transaction: %Ecto.Association.NotLoaded{} | Transaction.t(),
                # transaction_hash: Hash.Full.t(),
                # index: non_neg_integer(),
                type: nil
            }

            View.render_to_string(
              TransactionLogView,
              "_logs.html",
              log: private_log,
              conn: conn,
              transaction: transaction
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
      {:restricted_access, _} ->
        TransactionController.set_not_found_view(conn, transaction_hash_string)

      :error ->
        TransactionController.set_invalid_view(conn, transaction_hash_string)

      {:error, :not_found} ->
        TransactionController.set_not_found_view(conn, transaction_hash_string)
    end
  end

  def index(conn, %{"transaction_id" => transaction_hash_string} = params) do
    with {:ok, transaction_hash} <- Chain.string_to_transaction_hash(transaction_hash_string),
         {:ok, transaction} <-
           Chain.hash_to_transaction(
             transaction_hash,
             necessity_by_association: %{
               :block => :optional,
               [created_contract_address: :names] => :optional,
               [from_address: :names] => :required,
               [to_address: :names] => :optional,
               [to_address: :smart_contract] => :optional,
               :token_transfers => :optional
             }
           ),
         {:ok, false} <-
           AccessHelpers.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <-
           AccessHelpers.restricted_access?(to_string(transaction.to_address_hash), params) do
      render(
        conn,
        "index.html",
        block_height: Chain.block_height(),
        show_token_transfers: Chain.transaction_has_token_transfers?(transaction_hash),
        current_path: Controller.current_full_path(conn),
        transaction: transaction,
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null()
      )
    else
      {:restricted_access, _} ->
        TransactionController.set_not_found_view(conn, transaction_hash_string)

      :error ->
        TransactionController.set_invalid_view(conn, transaction_hash_string)

      {:error, :not_found} ->
        TransactionController.set_not_found_view(conn, transaction_hash_string)
    end
  end
end
