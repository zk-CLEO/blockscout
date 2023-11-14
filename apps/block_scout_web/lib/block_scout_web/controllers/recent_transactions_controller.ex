defmodule BlockScoutWeb.RecentTransactionsController do
  use BlockScoutWeb, :controller

  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.Hash
  alias Phoenix.View
  alias BlockScoutWeb.Privacy.PrivacyVerify

  {:ok, burn_address_hash} =
    Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")

  @burn_address_hash burn_address_hash

  def index(conn, _params) do
    if ajax?(conn) do
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
      recent_transactions =
        Chain.recent_collated_transactions(
          necessity_by_association: %{
            :block => :required,
            [created_contract_address: :names] => :optional,
            [from_address: :names] => :optional,
            [to_address: :names] => :optional
          },
          paging_options: %PagingOptions{page_size: 5}
        )

      transactions =
        Enum.map(recent_transactions, fn transaction ->
          %Chain.Transaction{
            from_address_hash: from_address_hash,
            to_address_hash: to_address_hash
          } = transaction

          if address_verified == true ||
               (wallet_login_hash != nil &&
                  (from_address_hash == wallet_login_hash || to_address_hash == wallet_login_hash)) do
            %{
              transaction_hash: Hash.to_string(transaction.hash),
              transaction_html:
                View.render_to_string(BlockScoutWeb.TransactionView, "_tile.html",
                  transaction: transaction,
                  burn_address_hash: @burn_address_hash,
                  conn: conn
                )
            }
          else
            %{
              transaction_hash: Hash.to_string(transaction.hash),
              transaction_html:
                View.render_to_string(BlockScoutWeb.TransactionView, "_empty.html",
                  transaction: transaction,
                  burn_address_hash: @burn_address_hash,
                  conn: conn
                )
            }
          end
        end)

      json(conn, %{transactions: transactions})
    else
      unprocessable_entity(conn)
    end
  end
end
