defmodule BlockScoutWeb.AddressTokenBalanceController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.AccessHelpers
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Address
  alias Indexer.Fetcher.TokenBalanceOnDemand
  alias BlockScoutWeb.Privacy.PrivacyVerify

  def index(conn, %{"address_id" => address_hash_string} = params) do
    with true <- ajax?(conn),
         {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string) do
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

      token_balances =
        address_hash
        |> Chain.fetch_last_token_balances()

      Task.start_link(fn ->
        TokenBalanceOnDemand.trigger_fetch(address_hash, token_balances)
      end)

      token_balances_with_price =
        token_balances
        |> Market.add_price()

      case AccessHelpers.restricted_access?(address_hash_string, params) do
        {:ok, false} ->
          if address_verified == true || wallet_login_hash == address_hash do
            conn
            |> put_status(200)
            |> put_layout(false)
            |> render("_token_balances.html",
              address_hash: Address.checksum(address_hash),
              token_balances: token_balances_with_price,
              conn: conn
            )
          else
            conn
            |> put_status(200)
            |> put_layout(false)
            |> render("_token_balances.html",
              address_hash: Address.checksum(address_hash),
              token_balances: [],
              conn: conn
            )
          end

        _ ->
          conn
          |> put_status(200)
          |> put_layout(false)
          |> render("_token_balances.html",
            address_hash: Address.checksum(address_hash),
            token_balances: [],
            conn: conn
          )
      end
    else
      _ ->
        not_found(conn)
    end
  end
end
