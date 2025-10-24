defmodule P2PMonitor.RLP.Decoder do
  @moduledoc """
  RLP (Recursive Length Prefix) decoding utilities for Ethereum data structures.

  This module provides functions to decode RLP-encoded binary data back into
  Elixir data structures.

  ## Examples

      iex> P2PMonitor.RLP.Decoder.decode(<<0x83, 0x64, 0x6f, 0x67>>)
      {:ok, "dog"}

      iex> P2PMonitor.RLP.Decoder.decode(<<0xc8, 0x83, 0x63, 0x61, 0x74, 0x83, 0x64, 0x6f, 0x67>>)
      {:ok, ["cat", "dog"]}
  """

  @doc """
  Decodes RLP-encoded binary data.

  ## Parameters
    * `data` - RLP-encoded binary

  ## Returns
    * `{:ok, decoded_data}` - Successfully decoded data
    * `{:error, reason}` - Decoding failed

  ## Examples

      iex> P2PMonitor.RLP.Decoder.decode(<<0x80>>)
      {:ok, ""}

      iex> P2PMonitor.RLP.Decoder.decode(<<0xc0>>)
      {:ok, []}
  """
  @spec decode(binary()) :: {:ok, any()} | {:error, atom()}
  def decode(data) when is_binary(data) do
    case ExRLP.decode(data) do
      decoded when is_binary(decoded) or is_list(decoded) ->
        {:ok, decoded}
      _ ->
        {:error, :invalid_rlp}
    end
  rescue
    _ -> {:error, :invalid_rlp}
  end

  @doc """
  Decodes RLP data, raising on error.

  ## Parameters
    * `data` - RLP-encoded binary

  ## Returns
    * Decoded data

  ## Raises
    * `RuntimeError` if decoding fails
  """
  @spec decode!(binary()) :: any()
  def decode!(data) do
    case decode(data) do
      {:ok, decoded} -> decoded
      {:error, reason} -> raise "RLP decode failed: #{reason}"
    end
  end

  @doc """
  Decodes a transaction from RLP format.

  Automatically detects transaction type based on the first byte.

  ## Parameters
    * `data` - RLP-encoded transaction binary

  ## Returns
    * `{:ok, transaction_map}` - Successfully decoded transaction
    * `{:error, reason}` - Decoding failed
  """
  @spec decode_transaction(binary()) :: {:ok, map()} | {:error, atom()}
  def decode_transaction(<<0x04, rest::binary>>) do
    # EIP-7702 transaction
    with {:ok, fields} <- decode(rest),
         true <- is_list(fields) do
      {:ok, parse_eip7702_transaction(fields)}
    else
      _ -> {:error, :invalid_transaction}
    end
  end

  def decode_transaction(<<0x03, rest::binary>>) do
    # EIP-4844 transaction
    with {:ok, fields} <- decode(rest),
         true <- is_list(fields) do
      {:ok, parse_eip4844_transaction(fields)}
    else
      _ -> {:error, :invalid_transaction}
    end
  end

  def decode_transaction(<<0x02, rest::binary>>) do
    # EIP-1559 transaction
    with {:ok, fields} <- decode(rest),
         true <- is_list(fields) do
      {:ok, parse_eip1559_transaction(fields)}
    else
      _ -> {:error, :invalid_transaction}
    end
  end

  def decode_transaction(<<0x01, rest::binary>>) do
    # EIP-2930 transaction
    with {:ok, fields} <- decode(rest),
         true <- is_list(fields) do
      {:ok, parse_eip2930_transaction(fields)}
    else
      _ -> {:error, :invalid_transaction}
    end
  end

  def decode_transaction(data) when is_binary(data) do
    # Legacy transaction
    with {:ok, fields} <- decode(data),
         true <- is_list(fields) do
      {:ok, parse_legacy_transaction(fields)}
    else
      _ -> {:error, :invalid_transaction}
    end
  end

  # Private functions

  defp parse_legacy_transaction(fields) when length(fields) >= 6 do
    [nonce, gas_price, gas_limit, to, value, data | rest] = fields

    base = %{
      type: :legacy,
      nonce: parse_integer(nonce),
      gas_price: parse_integer(gas_price),
      gas_limit: parse_integer(gas_limit),
      to: to,
      value: parse_integer(value),
      data: data
    }

    # Add signature if present
    case rest do
      [v, r, s] ->
        Map.merge(base, %{
          v: parse_integer(v),
          r: parse_integer(r),
          s: parse_integer(s)
        })
      _ ->
        base
    end
  end

  defp parse_legacy_transaction(_), do: %{type: :legacy}

  defp parse_eip1559_transaction(fields) when length(fields) >= 9 do
    [chain_id, nonce, max_priority_fee, max_fee, gas_limit, to, value, data, access_list | rest] = fields

    base = %{
      type: :eip1559,
      chain_id: parse_integer(chain_id),
      nonce: parse_integer(nonce),
      max_priority_fee_per_gas: parse_integer(max_priority_fee),
      max_fee_per_gas: parse_integer(max_fee),
      gas_limit: parse_integer(gas_limit),
      to: to,
      value: parse_integer(value),
      data: data,
      access_list: access_list
    }

    # Add signature if present
    case rest do
      [v, r, s] ->
        Map.merge(base, %{
          v: parse_integer(v),
          r: parse_integer(r),
          s: parse_integer(s)
        })
      _ ->
        base
    end
  end

  defp parse_eip1559_transaction(_), do: %{type: :eip1559}

  defp parse_eip2930_transaction(fields) when length(fields) >= 8 do
    [chain_id, nonce, gas_price, gas_limit, to, value, data, access_list | rest] = fields

    base = %{
      type: :eip2930,
      chain_id: parse_integer(chain_id),
      nonce: parse_integer(nonce),
      gas_price: parse_integer(gas_price),
      gas_limit: parse_integer(gas_limit),
      to: to,
      value: parse_integer(value),
      data: data,
      access_list: access_list
    }

    # Add signature if present
    case rest do
      [v, r, s] ->
        Map.merge(base, %{
          v: parse_integer(v),
          r: parse_integer(r),
          s: parse_integer(s)
        })
      _ ->
        base
    end
  end

  defp parse_eip2930_transaction(_), do: %{type: :eip2930}

  defp parse_eip4844_transaction(fields) when length(fields) >= 11 do
    [chain_id, nonce, max_priority_fee, max_fee, gas_limit, to, value, data, access_list, max_fee_per_blob_gas, blob_versioned_hashes | rest] = fields

    base = %{
      type: :eip4844,
      chain_id: parse_integer(chain_id),
      nonce: parse_integer(nonce),
      max_priority_fee_per_gas: parse_integer(max_priority_fee),
      max_fee_per_gas: parse_integer(max_fee),
      gas_limit: parse_integer(gas_limit),
      to: to,
      value: parse_integer(value),
      data: data,
      access_list: access_list,
      max_fee_per_blob_gas: parse_integer(max_fee_per_blob_gas),
      blob_versioned_hashes: blob_versioned_hashes
    }

    # Add signature if present
    case rest do
      [v, r, s] ->
        Map.merge(base, %{
          v: parse_integer(v),
          r: parse_integer(r),
          s: parse_integer(s)
        })
      _ ->
        base
    end
  end

  defp parse_eip4844_transaction(_), do: %{type: :eip4844}

  defp parse_eip7702_transaction(fields) when length(fields) >= 10 do
    [chain_id, nonce, max_priority_fee, max_fee, gas_limit, to, value, data, access_list, authorization_list | rest] = fields

    base = %{
      type: :eip7702,
      chain_id: parse_integer(chain_id),
      nonce: parse_integer(nonce),
      max_priority_fee_per_gas: parse_integer(max_priority_fee),
      max_fee_per_gas: parse_integer(max_fee),
      gas_limit: parse_integer(gas_limit),
      to: to,
      value: parse_integer(value),
      data: data,
      access_list: access_list,
      authorization_list: parse_authorization_list(authorization_list)
    }

    # Add signature if present (EIP-7702 uses signature_y_parity instead of v)
    case rest do
      [y_parity, r, s] ->
        Map.merge(base, %{
          signature_y_parity: parse_integer(y_parity),
          signature_r: parse_integer(r),
          signature_s: parse_integer(s)
        })
      _ ->
        base
    end
  end

  defp parse_eip7702_transaction(_), do: %{type: :eip7702}

  defp parse_authorization_list(list) when is_list(list) do
    Enum.map(list, fn
      [chain_id, address, nonce, y_parity, r, s] ->
        %{
          chain_id: parse_integer(chain_id),
          address: address,
          nonce: parse_nonce_list(nonce),
          y_parity: parse_integer(y_parity),
          r: parse_integer(r),
          s: parse_integer(s)
        }
      _ ->
        %{}
    end)
  end
  defp parse_authorization_list(_), do: []

  defp parse_nonce_list(data) when is_list(data), do: data
  defp parse_nonce_list(data) when is_binary(data) and byte_size(data) == 0, do: []
  defp parse_nonce_list(data), do: [parse_integer(data)]

  defp parse_integer(data) when data == "" or data == <<>>, do: 0
  defp parse_integer(data) when is_binary(data) do
    :binary.decode_unsigned(data, :big)
  end
  defp parse_integer(data) when is_integer(data), do: data
end
