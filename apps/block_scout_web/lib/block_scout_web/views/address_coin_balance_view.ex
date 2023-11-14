defmodule BlockScoutWeb.AddressCoinBalanceView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.AccessHelpers
  alias Explorer.Chain.Wei

  def format(%Wei{} = value) do
    String.replace(format_wei_value(value, :ether),"Ether","CLEO")
  end

  def delta_arrow(value) do
    if value.sign == 1 do
      "▲"
    else
      "▼"
    end
  end

  def delta_sign(value) do
    if value.sign == 1 do
      "Positive"
    else
      "Negative"
    end
  end

  def format_delta(%Decimal{} = value) do
    String.replace(
    value
    |> Decimal.abs()
    |> Wei.from(:wei)
    |> format_wei_value(:ether), "Ether", "CLEO")
  end
end
