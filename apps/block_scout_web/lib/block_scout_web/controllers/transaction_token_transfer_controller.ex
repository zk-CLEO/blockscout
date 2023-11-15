defmodule BlockScoutWeb.TransactionTokenTransferController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.{
    AccessHelpers,
    Controller,
    TransactionController,
    TransactionTokenTransferView
  }

  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token
  alias Phoenix.View
  alias BlockScoutWeb.Privacy.PrivacyVerify

  {:ok, burn_address_hash} =
    Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")

  @burn_address_hash burn_address_hash

  def index(conn, %{"transaction_id" => transaction_hash_string, "type" => "JSON"} = params) do
    with {:ok, transaction_hash} <- Chain.string_to_transaction_hash(transaction_hash_string),
         :ok <- Chain.check_transaction_exists(transaction_hash),
         {:ok, transaction} <-
           Chain.hash_to_transaction(
             transaction_hash,
             []
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
              from_address: :required,
              to_address: :required,
              token: :required
            }
          ],
          paging_options(params)
        )

      token_transfers_plus_one =
        Chain.transaction_to_token_transfers(transaction_hash, full_options)

      {token_transfers, next_page} = split_list_by_page(token_transfers_plus_one)

      next_page_url =
        case next_page_params(next_page, token_transfers, params) do
          nil ->
            nil

          next_page_params ->
            transaction_token_transfer_path(
              conn,
              :index,
              transaction_hash,
              Map.delete(next_page_params, "type")
            )
        end

      items =
        token_transfers
        |> Enum.map(fn transfer ->
          %Chain.TokenTransfer{
            from_address_hash: from_address_hash,
            to_address_hash: to_address_hash
          } = transfer

          if address_verified == true ||
               (wallet_login_hash != nil &&
                  (from_address_hash == wallet_login_hash || to_address_hash == wallet_login_hash)) do
            View.render_to_string(
              TransactionTokenTransferView,
              "_token_transfer.html",
              token_transfer: transfer,
              burn_address_hash: @burn_address_hash,
              conn: conn
            )
          else
            View.render_to_string(
              TransactionTokenTransferView,
              "_empty.html",
              token_transfer: transfer,
              burn_address_hash: @burn_address_hash,
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
          block_height: Chain.block_height(),
          current_path: Controller.current_full_path(conn),
          show_token_transfers: true,
          transaction: transaction
        )
      else
        render(
          conn,
          "index_private.html",
          exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
          block_height: Chain.block_height(),
          current_path: Controller.current_full_path(conn),
          show_token_transfers: true,
          transaction: transaction
        )
      end
    else
      :not_found ->
        TransactionController.set_not_found_view(conn, transaction_hash_string)

      :error ->
        TransactionController.set_invalid_view(conn, transaction_hash_string)

      {:error, :not_found} ->
        TransactionController.set_not_found_view(conn, transaction_hash_string)

      {:restricted_access, _} ->
        TransactionController.set_not_found_view(conn, transaction_hash_string)
    end
  end
end
