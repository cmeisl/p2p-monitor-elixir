defmodule P2PMonitor.Crypto.Keccak do
  @moduledoc """
  Keccak-256 hashing utilities for Ethereum.

  Ethereum uses Keccak-256 (not SHA3-256) for most hashing operations, including:
  - Ethereum addresses (last 20 bytes of Keccak-256 hash of public key)
  - Transaction hashes
  - Block hashes
  - Contract addresses

  ## Examples

      iex> P2PMonitor.Crypto.Keccak.hash("hello")
      <<28, 138, 255, 149, 6, 133, 194, 237, 75, 195, 23, 79, 52, 114, 40, 123,
        86, 217, 81, 123, 156, 148, 129, 39, 49, 154, 9, 167, 163, 109, 234, 200>>
  """

  @doc """
  Computes the Keccak-256 hash of the given data.

  ## Parameters
    * `data` - Binary data to hash

  ## Returns
    * 32-byte (256-bit) binary hash

  ## Examples

      iex> hash = P2PMonitor.Crypto.Keccak.hash("")
      iex> byte_size(hash)
      32

      iex> hash = P2PMonitor.Crypto.Keccak.hash("test")
      iex> byte_size(hash)
      32
  """
  @spec hash(binary()) :: binary()
  def hash(data) when is_binary(data) do
    ExKeccak.hash_256(data)
  end

  @doc """
  Computes the Keccak-256 hash and returns it as a hex string.

  ## Parameters
    * `data` - Binary data to hash

  ## Returns
    * 64-character hex string (with optional "0x" prefix)

  ## Examples

      iex> P2PMonitor.Crypto.Keccak.hash_hex("hello")
      "1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8"

      iex> P2PMonitor.Crypto.Keccak.hash_hex("hello", prefix: true)
      "0x1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8"
  """
  @spec hash_hex(binary(), keyword()) :: String.t()
  def hash_hex(data, opts \\ []) when is_binary(data) do
    hash = hash(data)
    hex = Base.encode16(hash, case: :lower)

    if Keyword.get(opts, :prefix, false) do
      "0x" <> hex
    else
      hex
    end
  end

  @doc """
  Computes an Ethereum address from a public key.

  The Ethereum address is derived by:
  1. Taking the Keccak-256 hash of the 64-byte public key (without the 0x04 prefix)
  2. Taking the last 20 bytes of the hash

  ## Parameters
    * `public_key` - 64-byte uncompressed public key (without 0x04 prefix)

  ## Returns
    * 20-byte Ethereum address

  ## Examples

      iex> public_key = <<1::512>>  # 64 bytes
      iex> address = P2PMonitor.Crypto.Keccak.public_key_to_address(public_key)
      iex> byte_size(address)
      20
  """
  @spec public_key_to_address(binary()) :: binary()
  def public_key_to_address(public_key) when byte_size(public_key) == 64 do
    public_key
    |> hash()
    |> binary_part(12, 20)  # Take last 20 bytes
  end

  def public_key_to_address(<<0x04, public_key::binary-size(64)>>) do
    # Handle public key with 0x04 prefix
    public_key_to_address(public_key)
  end

  @doc """
  Computes an Ethereum address from a public key and returns it as a hex string.

  ## Parameters
    * `public_key` - 64-byte uncompressed public key (with or without 0x04 prefix)
    * `opts` - Options for formatting (checksum: boolean, prefix: boolean)

  ## Returns
    * 40-character hex string (with optional "0x" prefix and optional checksum)

  ## Examples

      iex> public_key = <<1::512>>
      iex> addr = P2PMonitor.Crypto.Keccak.public_key_to_address_hex(public_key)
      iex> String.length(addr)
      40
      iex> public_key = <<1::512>>
      iex> addr_with_prefix = P2PMonitor.Crypto.Keccak.public_key_to_address_hex(public_key, prefix: true)
      iex> String.starts_with?(addr_with_prefix, "0x")
      true
  """
  @spec public_key_to_address_hex(binary(), keyword()) :: String.t()
  def public_key_to_address_hex(public_key, opts \\ []) do
    address = public_key_to_address(public_key)
    hex = Base.encode16(address, case: :lower)

    hex = if Keyword.get(opts, :checksum, false) do
      checksum_address(hex)
    else
      hex
    end

    if Keyword.get(opts, :prefix, false) do
      "0x" <> hex
    else
      hex
    end
  end

  @doc """
  Applies EIP-55 checksum encoding to an Ethereum address.

  EIP-55 uses mixed case to encode a checksum into the address itself.

  ## Parameters
    * `address` - 40-character hex address (without 0x prefix)

  ## Returns
    * Checksummed address

  ## Examples

      iex> P2PMonitor.Crypto.Keccak.checksum_address("5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
      "5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"
  """
  @spec checksum_address(String.t()) :: String.t()
  def checksum_address(address) when is_binary(address) do
    # Remove 0x prefix if present
    address = String.replace_prefix(address, "0x", "")
    address_lower = String.downcase(address)

    # Hash the lowercase address
    hash = hash(address_lower)
    hash_hex = Base.encode16(hash, case: :lower)

    # Apply checksum
    address_lower
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.map(fn {char, index} ->
      # Get the corresponding hex digit from the hash
      hash_digit = String.at(hash_hex, index)
      hash_value = String.to_integer(hash_digit, 16)

      # If hash digit is >= 8, capitalize the address character
      if hash_value >= 8 do
        String.upcase(char)
      else
        char
      end
    end)
    |> Enum.join()
  end

  @doc """
  Validates an EIP-55 checksummed address.

  ## Parameters
    * `address` - Ethereum address with checksum

  ## Returns
    * `true` if checksum is valid, `false` otherwise
  """
  @spec valid_checksum?(String.t()) :: boolean()
  def valid_checksum?(address) when is_binary(address) do
    address = String.replace_prefix(address, "0x", "")

    # If address is all lowercase or all uppercase, it's valid (no checksum)
    if address == String.downcase(address) or address == String.upcase(address) do
      true
    else
      # Validate checksum
      expected = checksum_address(address)
      address == expected
    end
  end
end
