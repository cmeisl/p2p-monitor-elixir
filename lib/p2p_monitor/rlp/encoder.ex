defmodule P2PMonitor.RLP.Encoder do
  @moduledoc """
  RLP (Recursive Length Prefix) encoding utilities for Ethereum data structures.

  This module provides functions to encode Elixir data structures into RLP format,
  which is used throughout the Ethereum protocol for efficient data serialization.

  ## Examples

      iex> P2PMonitor.RLP.Encoder.encode("dog")
      <<0x83, 0x64, 0x6f, 0x67>>

      iex> P2PMonitor.RLP.Encoder.encode(["cat", "dog"])
      <<0xc8, 0x83, 0x63, 0x61, 0x74, 0x83, 0x64, 0x6f, 0x67>>
  """

  @doc """
  Encodes an Elixir term into RLP format.

  Supports:
  - Binary strings
  - Integers (converted to big-endian binary)
  - Lists (recursive encoding)

  ## Parameters
    * `data` - The data to encode (binary, integer, or list)

  ## Returns
    * Binary RLP-encoded data

  ## Examples

      iex> P2PMonitor.RLP.Encoder.encode("")
      <<0x80>>

      iex> P2PMonitor.RLP.Encoder.encode(0)
      <<0x80>>

      iex> P2PMonitor.RLP.Encoder.encode([])
      <<0xc0>>
  """
  @spec encode(binary() | integer() | list()) :: binary()
  def encode(data) do
    ExRLP.encode(normalize(data))
  end

  @doc """
  Encodes a transaction into RLP format.

  Transactions are encoded as a list of fields in a specific order.

  ## Parameters
    * `tx` - A map containing transaction fields

  ## Returns
    * Binary RLP-encoded transaction

  ## Examples

      iex> tx = %{
      ...>   nonce: 0,
      ...>   gas_price: 20_000_000_000,
      ...>   gas_limit: 21_000,
      ...>   to: <<0x12, 0x34>>,
      ...>   value: 1_000_000_000_000_000_000,
      ...>   data: <<>>
      ...> }
      iex> is_binary(P2PMonitor.RLP.Encoder.encode_transaction(tx))
      true
  """
  @spec encode_transaction(map()) :: binary()
  def encode_transaction(%{type: :legacy} = tx) do
    encode_legacy_transaction(tx)
  end

  def encode_transaction(%{type: :eip1559} = tx) do
    encode_eip1559_transaction(tx)
  end

  def encode_transaction(%{type: :eip2930} = tx) do
    encode_eip2930_transaction(tx)
  end

  def encode_transaction(%{type: :eip4844} = tx) do
    encode_eip4844_transaction(tx)
  end

  def encode_transaction(tx) do
    # Default to legacy if no type specified
    encode_legacy_transaction(tx)
  end

  # Private functions

  defp normalize(data) when is_binary(data), do: data
  defp normalize(0), do: ""
  defp normalize(data) when is_integer(data) and data > 0 do
    data |> :binary.encode_unsigned(:big) |> trim_leading_zeros()
  end
  defp normalize(data) when is_list(data), do: Enum.map(data, &normalize/1)
  defp normalize(nil), do: ""

  defp trim_leading_zeros(<<0, rest::binary>>), do: trim_leading_zeros(rest)
  defp trim_leading_zeros(<<>>), do: ""
  defp trim_leading_zeros(data), do: data

  defp encode_legacy_transaction(tx) do
    fields = [
      tx[:nonce] || 0,
      tx[:gas_price] || 0,
      tx[:gas_limit] || tx[:gas] || 21_000,
      tx[:to] || "",
      tx[:value] || 0,
      tx[:data] || tx[:input] || ""
    ]

    # Add signature fields if present
    fields = if tx[:v] do
      fields ++ [tx[:v], tx[:r] || 0, tx[:s] || 0]
    else
      fields
    end

    encode(fields)
  end

  defp encode_eip1559_transaction(tx) do
    fields = [
      tx[:chain_id] || 1,
      tx[:nonce] || 0,
      tx[:max_priority_fee_per_gas] || 0,
      tx[:max_fee_per_gas] || 0,
      tx[:gas_limit] || tx[:gas] || 21_000,
      tx[:to] || "",
      tx[:value] || 0,
      tx[:data] || tx[:input] || "",
      tx[:access_list] || []
    ]

    # Add signature fields if present
    fields = if tx[:v] do
      fields ++ [tx[:v], tx[:r] || 0, tx[:s] || 0]
    else
      fields
    end

    # EIP-1559 transactions are prefixed with 0x02
    <<0x02>> <> encode(fields)
  end

  defp encode_eip2930_transaction(tx) do
    fields = [
      tx[:chain_id] || 1,
      tx[:nonce] || 0,
      tx[:gas_price] || 0,
      tx[:gas_limit] || tx[:gas] || 21_000,
      tx[:to] || "",
      tx[:value] || 0,
      tx[:data] || tx[:input] || "",
      tx[:access_list] || []
    ]

    # Add signature fields if present
    fields = if tx[:v] do
      fields ++ [tx[:v], tx[:r] || 0, tx[:s] || 0]
    else
      fields
    end

    # EIP-2930 transactions are prefixed with 0x01
    <<0x01>> <> encode(fields)
  end

  defp encode_eip4844_transaction(tx) do
    fields = [
      tx[:chain_id] || 1,
      tx[:nonce] || 0,
      tx[:max_priority_fee_per_gas] || 0,
      tx[:max_fee_per_gas] || 0,
      tx[:gas_limit] || tx[:gas] || 21_000,
      tx[:to] || "",
      tx[:value] || 0,
      tx[:data] || tx[:input] || "",
      tx[:access_list] || [],
      tx[:max_fee_per_blob_gas] || 0,
      tx[:blob_versioned_hashes] || []
    ]

    # Add signature fields if present
    fields = if tx[:v] do
      fields ++ [tx[:v], tx[:r] || 0, tx[:s] || 0]
    else
      fields
    end

    # EIP-4844 transactions are prefixed with 0x03
    <<0x03>> <> encode(fields)
  end
end
