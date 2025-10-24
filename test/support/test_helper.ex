defmodule P2PMonitor.TestHelper do
  @moduledoc """
  Helper utilities for testing P2P Monitor functionality.
  """

  @doc """
  Generates a random binary of the specified size.
  """
  @spec random_binary(non_neg_integer()) :: binary()
  def random_binary(size) do
    :crypto.strong_rand_bytes(size)
  end

  @doc """
  Generates a random Ethereum address (20 bytes).
  """
  @spec random_address() :: binary()
  def random_address do
    random_binary(20)
  end

  @doc """
  Generates a random transaction hash (32 bytes).
  """
  @spec random_hash() :: binary()
  def random_hash do
    random_binary(32)
  end

  @doc """
  Generates a random private key (32 bytes).
  """
  @spec random_private_key() :: binary()
  def random_private_key do
    random_binary(32)
  end

  @doc """
  Converts a hex string to binary, handling "0x" prefix.
  """
  @spec hex_to_binary(String.t()) :: binary()
  def hex_to_binary("0x" <> hex), do: hex_to_binary(hex)
  def hex_to_binary(hex) do
    Base.decode16!(hex, case: :mixed)
  end

  @doc """
  Converts binary to hex string with optional "0x" prefix.
  """
  @spec binary_to_hex(binary(), keyword()) :: String.t()
  def binary_to_hex(binary, opts \\ []) do
    hex = Base.encode16(binary, case: :lower)
    if Keyword.get(opts, :prefix, false) do
      "0x" <> hex
    else
      hex
    end
  end

  @doc """
  Asserts that two binaries are equal, providing helpful error messages.
  """
  defmacro assert_binary_equal(left, right) do
    quote do
      left_val = unquote(left)
      right_val = unquote(right)
      
      if left_val != right_val do
        flunk """
        Binary values not equal:
        Left:  #{Base.encode16(left_val, case: :lower)}
        Right: #{Base.encode16(right_val, case: :lower)}
        """
      end
    end
  end

  @doc """
  Generates a valid secp256k1 private key.
  Ensures the key is within valid range (1 to n-1 where n is curve order).
  """
  @spec generate_valid_private_key() :: binary()
  def generate_valid_private_key do
    # secp256k1 curve order
    n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
    
    key = :crypto.strong_rand_bytes(32)
    key_int = :binary.decode_unsigned(key, :big)
    
    # Ensure key is in valid range [1, n-1]
    if key_int > 0 and key_int < n do
      key
    else
      generate_valid_private_key()
    end
  end

  @doc """
  Generates a public key from a private key.
  """
  @spec private_key_to_public_key(binary()) :: binary()
  def private_key_to_public_key(private_key) do
    case ExSecp256k1.create_public_key(private_key) do
      {:ok, <<0x04, public_key::binary-size(64)>>} -> public_key
      {:ok, public_key} when byte_size(public_key) == 64 -> public_key
      _ -> raise "Failed to generate public key"
    end
  end

  @doc """
  Creates a signed transaction for testing.
  """
  @spec create_signed_transaction(keyword()) :: map()
  def create_signed_transaction(opts \\ []) do
    private_key = Keyword.get(opts, :private_key, generate_valid_private_key())
    nonce = Keyword.get(opts, :nonce, 0)
    gas_price = Keyword.get(opts, :gas_price, 20_000_000_000)
    gas_limit = Keyword.get(opts, :gas_limit, 21_000)
    to = Keyword.get(opts, :to, random_address())
    value = Keyword.get(opts, :value, 1_000_000_000_000_000_000)
    data = Keyword.get(opts, :data, <<>>)
    chain_id = Keyword.get(opts, :chain_id, 1)

    # Create transaction for signing
    tx_data = [nonce, gas_price, gas_limit, to, value, data, chain_id, 0, 0]
    rlp_encoded = ExRLP.encode(tx_data)
    message_hash = P2PMonitor.Crypto.Keccak.hash(rlp_encoded)

    # Sign the transaction
    {:ok, signature} = P2PMonitor.Crypto.Signature.sign(message_hash, private_key, chain_id: chain_id)

    %{
      nonce: nonce,
      gas_price: gas_price,
      gas_limit: gas_limit,
      to: to,
      value: value,
      data: data,
      v: signature.v,
      r: signature.r,
      s: signature.s,
      type: :legacy,
      chain_id: chain_id
    }
  end
end
