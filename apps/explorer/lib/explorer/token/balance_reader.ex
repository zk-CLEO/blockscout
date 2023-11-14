defmodule Explorer.Token.BalanceReader do
  @moduledoc """
  Reads Token's balances using Smart Contract functions from the blockchain.
  """

  alias Explorer.SmartContract.Reader

  @balance_function_abi [
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [
        %{
          "type" => "uint256",
          "name" => "balance"
        }
      ],
      "name" => "balanceOf",
      "inputs" => [
        %{
          "type" => "address",
          "name" => "tokenOwner"
        }
      ],
      "constant" => true
    }
  ]

  @erc1155_balance_function_abi [
    %{
      "constant" => true,
      "inputs" => [%{"name" => "_owner", "type" => "address"}, %{"name" => "_id", "type" => "uint256"}],
      "name" => "balanceOf",
      "outputs" => [%{"name" => "", "type" => "uint256"}],
      "payable" => false,
      "stateMutability" => "view",
      "type" => "function"
    }
  ]

  @predeployed_eth_address "0x000000000000000000000000000000000000800a"
  @eth_method_id "9cc7f708"

  @spec get_balances_of([
          %{token_contract_address_hash: String.t(), address_hash: String.t(), block_number: non_neg_integer()}
        ]) :: [{:ok, non_neg_integer()} | {:error, String.t()}]
  def get_balances_of(token_balance_requests) do
    token_balance_requests
    |> Enum.map(&format_balance_request/1)
    |> Reader.query_contracts(@balance_function_abi)
    |> Enum.map(&format_balance_result/1)
  end

  @spec get_balances_of_with_abi(
          [
            %{token_contract_address_hash: String.t(), address_hash: String.t(), block_number: non_neg_integer()}
          ],
          [%{}]
        ) :: [{:ok, non_neg_integer()} | {:error, String.t()}]
  def get_balances_of_with_abi(token_balance_requests, abi) do
    formatted_balances_requests =
      if abi == @erc1155_balance_function_abi do
        token_balance_requests
        |> Enum.map(&format_erc_1155_balance_request/1)
      else
        token_balance_requests
        |> Enum.map(&format_balance_request/1)
      end

    if Enum.count(formatted_balances_requests) > 0 do
      formatted_balances_requests
      |> Reader.query_contracts(abi)
      |> Enum.map(&format_balance_result/1)
    else
      []
    end
  end

  defp format_balance_request(%{
         address_hash: address_hash,
         block_number: block_number,
         token_contract_address_hash: token_contract_address_hash
       }) do
    # Change method id for getting balance of ZkSync Ether.
    method_id =
      if token_contract_address_hash |> to_string() |> String.downcase() == @predeployed_eth_address do
        @eth_method_id
      else
        "70a08231"
      end

    %{
      contract_address: token_contract_address_hash,
      method_id: method_id,
      args: [address_hash],
      block_number: block_number,
      from: address_hash
    }
  end

  defp format_erc_1155_balance_request(%{
         address_hash: address_hash,
         block_number: block_number,
         token_contract_address_hash: token_contract_address_hash,
         token_id: token_id
       }) do
    %{
      contract_address: token_contract_address_hash,
      method_id: "00fdd58e",
      args: [address_hash, token_id],
      block_number: block_number
    }
  end

  defp format_balance_result({:ok, [balance]}) do
    {:ok, balance}
  end

  defp format_balance_result({:error, error_message}) do
    {:error, error_message}
  end
end
