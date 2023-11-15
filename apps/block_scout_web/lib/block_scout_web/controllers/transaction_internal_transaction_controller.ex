defmodule BlockScoutWeb.TransactionInternalTransactionController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.{AccessHelpers, Controller, InternalTransactionView, TransactionController}
  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token
  alias Phoenix.View
  alias BlockScoutWeb.Privacy.PrivacyVerify

  def index(conn, %{"transaction_id" => transaction_hash_string, "type" => "JSON"} = params) do
    with {:ok, transaction_hash} <- Chain.string_to_transaction_hash(transaction_hash_string),
         :ok <- Chain.check_transaction_exists(transaction_hash),
         {:ok, transaction} <- Chain.hash_to_transaction(transaction_hash, []),
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
              [created_contract_address: :names] => :optional,
              [from_address: :names] => :optional,
              [to_address: :names] => :optional,
              [transaction: :block] => :optional
            }
          ],
          paging_options(params)
        )

      internal_transactions_plus_one =
        Chain.transaction_to_internal_transactions(transaction_hash, full_options)

      {internal_transactions, next_page} = split_list_by_page(internal_transactions_plus_one)

      next_page_path =
        case next_page_params(next_page, internal_transactions, params) do
          nil ->
            nil

          next_page_params ->
            transaction_internal_transaction_path(
              conn,
              :index,
              transaction_hash,
              Map.delete(next_page_params, "type")
            )
        end

      items =
        internal_transactions
        |> Enum.map(fn internal_transaction ->
          %Chain.InternalTransaction{
            from_address_hash: from_address_hash,
            to_address_hash: to_address_hash
          } = internal_transaction

          if address_verified == true ||
               (wallet_login_hash != nil &&
                  (from_address_hash == wallet_login_hash || to_address_hash == wallet_login_hash)) do
            View.render_to_string(
              InternalTransactionView,
              "_tile.html",
              internal_transaction: internal_transaction
            )
          else
            View.render_to_string(
              InternalTransactionView,
              "_empty.html",
              internal_transaction: internal_transaction
            )
          end
        end)

      json(
        conn,
        %{
          items: items,
          next_page_path: next_page_path
        }
      )
    else
      {:restricted_access, _} ->
        TransactionController.set_not_found_view(conn, transaction_hash_string)

      :error ->
        TransactionController.set_invalid_view(conn, transaction_hash_string)

      {:error, :not_found} ->
        TransactionController.set_not_found_view(conn, transaction_hash_string)

      :not_found ->
        TransactionController.set_not_found_view(conn, transaction_hash_string)
    end
  end

  def index(conn, %{"transaction_id" => transaction_hash_string} = params) do
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
    with {:ok, transaction_hash} <- Chain.string_to_transaction_hash(transaction_hash_string),
         {:ok, transaction} <-
           Chain.hash_to_transaction(
             transaction_hash,
             necessity_by_association: %{
               :block => :optional,
               [created_contract_address: :names] => :optional,
               [from_address: :names] => :optional,
               [to_address: :names] => :optional,
               [to_address: :smart_contract] => :optional,
               :token_transfers => :optional
             }
           ),
         {:ok, false} <-
           AccessHelpers.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <-
           AccessHelpers.restricted_access?(to_string(transaction.to_address_hash), params) do
      %Chain.Transaction{
        from_address_hash: from_address_hash,
        to_address_hash: to_address_hash
      } = transaction

      if address_verified == true ||
           (wallet_login_hash != nil &&
              (from_address_hash == wallet_login_hash || to_address_hash == wallet_login_hash)) do
        render(
          conn,
          "index.html",
          exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
          current_path: Controller.current_full_path(conn),
          block_height: Chain.block_height(),
          show_token_transfers: Chain.transaction_has_token_transfers?(transaction_hash),
          transaction: transaction
        )
      else
        render(
          conn,
          "index_private.html",
          exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
          current_path: Controller.current_full_path(conn),
          block_height: Chain.block_height(),
          show_token_transfers: Chain.transaction_has_token_transfers?(transaction_hash),
          transaction: transaction
        )
      end
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
