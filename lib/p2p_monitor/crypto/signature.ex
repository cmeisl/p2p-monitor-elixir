defmodule P2PMonitor.Crypto.Signature do
  @moduledoc """
  ECDSA signature utilities using the secp256k1 curve for Ethereum transactions.

  Ethereum uses ECDSA (Elliptic Curve Digital Signature Algorithm) with the secp256k1
  curve for signing transactions and deriving addresses from signatures.
  """

  alias P2PMonitor.Crypto.Keccak

  @type signature :: %{
    v: non_neg_integer(),
    r: non_neg_integer(),
    s: non_neg_integer()
  }

  @doc """
  Recovers the public key from a signature and message hash.

  ## Parameters
    * `message_hash` - 32-byte Keccak-256 hash of the message
    * `signature` - Map containing v, r, and s values
    * `opts` - Options (chain_id: integer for EIP-155)

  ## Returns
    * `{:ok, public_key}` - 64-byte uncompressed public key
    * `{:error, reason}` - Recovery failed

  ## Examples

      iex> message_hash = <<1::256>>
      iex> signature = %{v: 27, r: 123, s: 456}
      iex> {:ok, _public_key} = P2PMonitor.Crypto.Signature.recover_public_key(message_hash, signature)
  """
  @spec recover_public_key(binary(), signature(), keyword()) :: {:ok, binary()} | {:error, atom()}
  def recover_public_key(message_hash, %{v: v, r: r, s: s}, opts \\ [])
      when byte_size(message_hash) == 32 do
    # Calculate recovery ID from v
    recovery_id = calculate_recovery_id(v, opts)

    # Convert r and s to binary
    r_bin = int_to_binary(r, 32)
    s_bin = int_to_binary(s, 32)

    # Concatenate r and s to create compact signature
    compact_sig = r_bin <> s_bin

    # Recover public key
    case ExSecp256k1.recover_compact(message_hash, compact_sig, :uncompressed, recovery_id) do
      {:ok, <<0x04, public_key::binary-size(64)>>} ->
        {:ok, public_key}

      {:ok, public_key} when byte_size(public_key) == 64 ->
        {:ok, public_key}

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, :recovery_failed}
    end
  rescue
    _ -> {:error, :invalid_signature}
  end

  @doc """
  Recovers the Ethereum address from a signature and message hash.

  ## Parameters
    * `message_hash` - 32-byte Keccak-256 hash of the message
    * `signature` - Map containing v, r, and s values
    * `opts` - Options (chain_id: integer for EIP-155)

  ## Returns
    * `{:ok, address}` - 20-byte Ethereum address
    * `{:error, reason}` - Recovery failed

  ## Examples

      iex> message_hash = <<1::256>>
      iex> signature = %{v: 27, r: 123, s: 456}
      iex> {:ok, _address} = P2PMonitor.Crypto.Signature.recover_address(message_hash, signature)
  """
  @spec recover_address(binary(), signature(), keyword()) :: {:ok, binary()} | {:error, atom()}
  def recover_address(message_hash, signature, opts \\ []) do
    case recover_public_key(message_hash, signature, opts) do
      {:ok, public_key} ->
        address = Keccak.public_key_to_address(public_key)
        {:ok, address}

      error ->
        error
    end
  end

  @doc """
  Signs a message hash with a private key.

  ## Parameters
    * `message_hash` - 32-byte hash to sign
    * `private_key` - 32-byte private key

  ## Returns
    * `{:ok, signature}` - Map with v, r, s values
    * `{:error, reason}` - Signing failed

  ## Examples

      iex> message_hash = :crypto.strong_rand_bytes(32)
      iex> private_key = :crypto.strong_rand_bytes(32)
      iex> {:ok, %{v: _v, r: _r, s: _s}} = P2PMonitor.Crypto.Signature.sign(message_hash, private_key)
  """
  @spec sign(binary(), binary(), keyword()) :: {:ok, signature()} | {:error, atom()}
  def sign(message_hash, private_key, opts \\ [])
      when byte_size(message_hash) == 32 and byte_size(private_key) == 32 do
    case ExSecp256k1.sign_compact(message_hash, private_key) do
      {:ok, signature, recovery_id} ->
        <<r_bin::binary-size(32), s_bin::binary-size(32)>> = signature

        r = :binary.decode_unsigned(r_bin, :big)
        s = :binary.decode_unsigned(s_bin, :big)

        # Calculate v from recovery_id and chain_id
        v = calculate_v(recovery_id, opts)

        {:ok, %{v: v, r: r, s: s}}

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, :signing_failed}
    end
  rescue
    _ -> {:error, :invalid_input}
  end

  @doc """
  Validates a signature's format and parameters.

  ## Parameters
    * `signature` - Map containing v, r, and s values

  ## Returns
    * `true` if signature is valid, `false` otherwise
  """
  @spec valid_signature?(signature()) :: boolean()
  def valid_signature?(%{v: v, r: r, s: s}) when is_integer(v) and is_integer(r) and is_integer(s) do
    # Check r and s are in valid range
    # secp256k1 curve order n
    n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141

    # r and s must be in [1, n-1]
    r > 0 and r < n and s > 0 and s < n
  end

  def valid_signature?(_), do: false

  @doc """
  Normalizes signature to low-s form (EIP-2).

  EIP-2 requires that s <= N/2 to prevent signature malleability.

  ## Parameters
    * `signature` - Map containing v, r, and s values

  ## Returns
    * Normalized signature map
  """
  @spec normalize_signature(signature()) :: signature()
  def normalize_signature(%{v: v, r: r, s: s} = sig) do
    n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
    half_n = div(n, 2)

    if s > half_n do
      # Flip s and v
      new_s = n - s
      new_v = if v == 27, do: 28, else: 27
      %{sig | v: new_v, s: new_s}
    else
      sig
    end
  end

  # Private functions

  defp calculate_recovery_id(v, opts) do
    chain_id = Keyword.get(opts, :chain_id)

    cond do
      # EIP-155 signature (v = chain_id * 2 + 35 + recovery_id)
      chain_id && v >= 35 ->
        v - chain_id * 2 - 35

      # Pre-EIP-155 signature (v = 27 or 28)
      v == 27 or v == 28 ->
        v - 27

      # Direct recovery_id
      v == 0 or v == 1 ->
        v

      true ->
        0
    end
  end

  defp calculate_v(recovery_id, opts) do
    chain_id = Keyword.get(opts, :chain_id)

    if chain_id do
      # EIP-155: v = chain_id * 2 + 35 + recovery_id
      chain_id * 2 + 35 + recovery_id
    else
      # Pre-EIP-155: v = 27 + recovery_id
      27 + recovery_id
    end
  end

  defp int_to_binary(num, size) when is_integer(num) and num >= 0 do
    num
    |> :binary.encode_unsigned(:big)
    |> pad_binary(size)
  end

  defp pad_binary(bin, target_size) when byte_size(bin) < target_size do
    padding_size = target_size - byte_size(bin)
    <<0::size(padding_size)-unit(8)>> <> bin
  end

  defp pad_binary(bin, _target_size), do: bin
end
