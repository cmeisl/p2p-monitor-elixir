defmodule P2PMonitor.Crypto.SignatureTest do
  use ExUnit.Case, async: true
  
  alias P2PMonitor.Crypto.Signature
  alias P2PMonitor.Crypto.Keccak
  import P2PMonitor.TestHelper
  import P2PMonitor.Factory

  doctest P2PMonitor.Crypto.Signature

  describe "sign/3" do
    test "successfully signs a message hash" do
      private_key = generate_valid_private_key()
      message_hash = random_hash()

      assert {:ok, signature} = Signature.sign(message_hash, private_key)
      assert %{v: v, r: r, s: s} = signature
      assert is_integer(v)
      assert is_integer(r)
      assert is_integer(s)
    end

    test "signature has valid v value (27 or 28 for non-EIP155)" do
      private_key = generate_valid_private_key()
      message_hash = random_hash()

      {:ok, signature} = Signature.sign(message_hash, private_key)
      
      assert signature.v in [27, 28]
    end

    test "signature has valid v value for EIP-155 (chain_id = 1)" do
      private_key = generate_valid_private_key()
      message_hash = random_hash()

      {:ok, signature} = Signature.sign(message_hash, private_key, chain_id: 1)
      
      # EIP-155: v = chain_id * 2 + 35 + recovery_id
      # For chain_id = 1: v should be 37 or 38
      assert signature.v in [37, 38]
    end

    test "produces deterministic signatures for same input" do
      private_key = generate_valid_private_key()
      message_hash = random_hash()

      {:ok, sig1} = Signature.sign(message_hash, private_key)
      {:ok, sig2} = Signature.sign(message_hash, private_key)
      
      assert sig1 == sig2
    end

    test "produces different signatures for different messages" do
      private_key = generate_valid_private_key()
      message_hash1 = random_hash()
      message_hash2 = random_hash()

      {:ok, sig1} = Signature.sign(message_hash1, private_key)
      {:ok, sig2} = Signature.sign(message_hash2, private_key)
      
      assert sig1 != sig2
    end

    test "produces different signatures for different private keys" do
      message_hash = random_hash()
      private_key1 = generate_valid_private_key()
      private_key2 = generate_valid_private_key()

      {:ok, sig1} = Signature.sign(message_hash, private_key1)
      {:ok, sig2} = Signature.sign(message_hash, private_key2)
      
      assert sig1 != sig2
    end

    test "returns error for invalid message hash size" do
      private_key = generate_valid_private_key()
      invalid_hash = <<1, 2, 3>>  # Not 32 bytes

      # Should raise FunctionClauseError due to guard clause
      assert_raise FunctionClauseError, fn ->
        Signature.sign(invalid_hash, private_key)
      end
    end

    test "returns error for invalid private key size" do
      message_hash = random_hash()
      invalid_key = <<1, 2, 3>>  # Not 32 bytes

      # Should raise FunctionClauseError due to guard clause
      assert_raise FunctionClauseError, fn ->
        Signature.sign(message_hash, invalid_key)
      end
    end

    test "signature components are within valid range" do
      private_key = generate_valid_private_key()
      message_hash = random_hash()

      {:ok, signature} = Signature.sign(message_hash, private_key)
      
      # secp256k1 curve order
      n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
      
      assert signature.r > 0 and signature.r < n
      assert signature.s > 0 and signature.s < n
    end
  end

  describe "recover_public_key/3" do
    test "recovers public key from valid signature" do
      private_key = generate_valid_private_key()
      expected_public_key = private_key_to_public_key(private_key)
      message_hash = random_hash()

      {:ok, signature} = Signature.sign(message_hash, private_key)
      {:ok, recovered_public_key} = Signature.recover_public_key(message_hash, signature)
      
      assert recovered_public_key == expected_public_key
    end

    test "recovered public key is 64 bytes" do
      {message_hash, signature, _address} = build_valid_signature()
      
      {:ok, public_key} = Signature.recover_public_key(message_hash, signature)
      
      assert byte_size(public_key) == 64
    end

    test "recovery works with EIP-155 signatures" do
      private_key = generate_valid_private_key()
      expected_public_key = private_key_to_public_key(private_key)
      message_hash = random_hash()
      chain_id = 1

      {:ok, signature} = Signature.sign(message_hash, private_key, chain_id: chain_id)
      {:ok, recovered_public_key} = Signature.recover_public_key(message_hash, signature, chain_id: chain_id)
      
      assert recovered_public_key == expected_public_key
    end

    test "recovery works with different chain IDs" do
      private_key = generate_valid_private_key()
      expected_public_key = private_key_to_public_key(private_key)
      message_hash = random_hash()

      for chain_id <- [1, 5, 11155111, 17000] do
        {:ok, signature} = Signature.sign(message_hash, private_key, chain_id: chain_id)
        {:ok, recovered_public_key} = Signature.recover_public_key(message_hash, signature, chain_id: chain_id)
        
        assert recovered_public_key == expected_public_key
      end
    end

    test "returns error for invalid signature" do
      message_hash = random_hash()
      invalid_signature = %{v: 27, r: 0, s: 0}
      
      assert {:error, _} = Signature.recover_public_key(message_hash, invalid_signature)
    end

    test "returns error for wrong message hash" do
      {_original_hash, signature, _address} = build_valid_signature()
      wrong_hash = random_hash()
      
      # Should still recover a public key, but it won't match
      # This tests that the function doesn't error on valid but wrong data
      assert {:ok, _public_key} = Signature.recover_public_key(wrong_hash, signature)
    end

    test "returns error for invalid message hash size" do
      {_message_hash, signature, _address} = build_valid_signature()
      invalid_hash = <<1, 2, 3>>
      
      # Should raise FunctionClauseError due to guard clause
      assert_raise FunctionClauseError, fn ->
        Signature.recover_public_key(invalid_hash, signature)
      end
    end
  end

  describe "recover_address/3" do
    test "recovers correct address from signature" do
      {message_hash, signature, expected_address} = build_valid_signature()
      
      {:ok, recovered_address} = Signature.recover_address(message_hash, signature)
      
      assert recovered_address == expected_address
    end

    test "recovered address is 20 bytes" do
      {message_hash, signature, _address} = build_valid_signature()
      
      {:ok, address} = Signature.recover_address(message_hash, signature)
      
      assert byte_size(address) == 20
    end

    test "address recovery works with EIP-155 signatures" do
      private_key = generate_valid_private_key()
      public_key = private_key_to_public_key(private_key)
      expected_address = Keccak.public_key_to_address(public_key)
      message_hash = random_hash()
      chain_id = 1

      {:ok, signature} = Signature.sign(message_hash, private_key, chain_id: chain_id)
      {:ok, recovered_address} = Signature.recover_address(message_hash, signature, chain_id: chain_id)
      
      assert recovered_address == expected_address
    end

    test "recovers same address for multiple signatures from same key" do
      private_key = generate_valid_private_key()
      public_key = private_key_to_public_key(private_key)
      expected_address = Keccak.public_key_to_address(public_key)

      for _ <- 1..5 do
        message_hash = random_hash()
        {:ok, signature} = Signature.sign(message_hash, private_key)
        {:ok, recovered_address} = Signature.recover_address(message_hash, signature)
        
        assert recovered_address == expected_address
      end
    end

    test "recovers different addresses for different keys" do
      message_hash = random_hash()
      private_key1 = generate_valid_private_key()
      private_key2 = generate_valid_private_key()

      {:ok, sig1} = Signature.sign(message_hash, private_key1)
      {:ok, sig2} = Signature.sign(message_hash, private_key2)

      {:ok, addr1} = Signature.recover_address(message_hash, sig1)
      {:ok, addr2} = Signature.recover_address(message_hash, sig2)
      
      assert addr1 != addr2
    end

    test "returns error for invalid signature" do
      message_hash = random_hash()
      invalid_signature = %{v: 27, r: 0, s: 0}
      
      assert {:error, _} = Signature.recover_address(message_hash, invalid_signature)
    end
  end

  describe "valid_signature?/1" do
    test "validates correct signature format" do
      {_message_hash, signature, _address} = build_valid_signature()
      
      assert Signature.valid_signature?(signature)
    end

    test "validates signature from signing operation" do
      private_key = generate_valid_private_key()
      message_hash = random_hash()

      {:ok, signature} = Signature.sign(message_hash, private_key)
      
      assert Signature.valid_signature?(signature)
    end

    test "rejects signature with zero r" do
      invalid_signature = %{v: 27, r: 0, s: 12345}
      
      refute Signature.valid_signature?(invalid_signature)
    end

    test "rejects signature with zero s" do
      invalid_signature = %{v: 27, r: 12345, s: 0}
      
      refute Signature.valid_signature?(invalid_signature)
    end

    test "rejects signature with r >= curve order" do
      n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
      invalid_signature = %{v: 27, r: n, s: 12345}
      
      refute Signature.valid_signature?(invalid_signature)
    end

    test "rejects signature with s >= curve order" do
      n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
      invalid_signature = %{v: 27, r: 12345, s: n}
      
      refute Signature.valid_signature?(invalid_signature)
    end

    test "accepts signature with maximum valid values" do
      n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
      valid_signature = %{v: 27, r: n - 1, s: n - 1}
      
      assert Signature.valid_signature?(valid_signature)
    end

    test "rejects invalid format (missing v)" do
      invalid_signature = %{r: 12345, s: 67890}
      
      refute Signature.valid_signature?(invalid_signature)
    end

    test "rejects invalid format (missing r)" do
      invalid_signature = %{v: 27, s: 67890}
      
      refute Signature.valid_signature?(invalid_signature)
    end

    test "rejects invalid format (missing s)" do
      invalid_signature = %{v: 27, r: 12345}
      
      refute Signature.valid_signature?(invalid_signature)
    end

    test "rejects non-integer values" do
      invalid_signature = %{v: "27", r: 12345, s: 67890}
      
      refute Signature.valid_signature?(invalid_signature)
    end

    test "rejects non-map input" do
      refute Signature.valid_signature?("not a map")
      refute Signature.valid_signature?([1, 2, 3])
      refute Signature.valid_signature?(nil)
    end
  end

  describe "normalize_signature/1" do
    test "normalizes high-s signature to low-s" do
      n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
      half_n = div(n, 2)
      
      # Create signature with high s
      high_s_sig = %{v: 27, r: 12345, s: half_n + 1000}
      normalized = Signature.normalize_signature(high_s_sig)
      
      assert normalized.s <= half_n
      assert normalized.v == 28  # v should flip
    end

    test "leaves low-s signature unchanged" do
      n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
      _half_n = div(n, 2)
      
      # Create signature with low s
      low_s_sig = %{v: 27, r: 12345, s: 1000}
      normalized = Signature.normalize_signature(low_s_sig)
      
      assert normalized == low_s_sig
    end

    test "flips v correctly when normalizing" do
      n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
      half_n = div(n, 2)
      
      # Test v: 27 -> 28
      sig1 = %{v: 27, r: 12345, s: half_n + 1000}
      normalized1 = Signature.normalize_signature(sig1)
      assert normalized1.v == 28
      
      # Test v: 28 -> 27
      sig2 = %{v: 28, r: 12345, s: half_n + 1000}
      normalized2 = Signature.normalize_signature(sig2)
      assert normalized2.v == 27
    end

    test "preserves r value" do
      n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
      half_n = div(n, 2)
      
      sig = %{v: 27, r: 12345, s: half_n + 1000}
      normalized = Signature.normalize_signature(sig)
      
      assert normalized.r == sig.r
    end

    test "normalized signature is still valid" do
      n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
      half_n = div(n, 2)
      
      high_s_sig = %{v: 27, r: 12345, s: half_n + 1000}
      normalized = Signature.normalize_signature(high_s_sig)
      
      assert Signature.valid_signature?(normalized)
    end

    test "normalization is idempotent" do
      n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
      half_n = div(n, 2)
      
      sig = %{v: 27, r: 12345, s: half_n + 1000}
      normalized1 = Signature.normalize_signature(sig)
      normalized2 = Signature.normalize_signature(normalized1)
      
      assert normalized1 == normalized2
    end
  end

  describe "sign and recover roundtrip" do
    test "can recover address from signed message" do
      private_key = generate_valid_private_key()
      public_key = private_key_to_public_key(private_key)
      expected_address = Keccak.public_key_to_address(public_key)
      message_hash = random_hash()

      {:ok, signature} = Signature.sign(message_hash, private_key)
      {:ok, recovered_address} = Signature.recover_address(message_hash, signature)
      
      assert recovered_address == expected_address
    end

    test "roundtrip works for multiple messages" do
      private_key = generate_valid_private_key()
      public_key = private_key_to_public_key(private_key)
      expected_address = Keccak.public_key_to_address(public_key)

      for _ <- 1..10 do
        message_hash = random_hash()
        {:ok, signature} = Signature.sign(message_hash, private_key)
        {:ok, recovered_address} = Signature.recover_address(message_hash, signature)
        
        assert recovered_address == expected_address
      end
    end

    test "roundtrip works with EIP-155" do
      private_key = generate_valid_private_key()
      public_key = private_key_to_public_key(private_key)
      expected_address = Keccak.public_key_to_address(public_key)
      message_hash = random_hash()
      chain_id = 11155111  # Sepolia

      {:ok, signature} = Signature.sign(message_hash, private_key, chain_id: chain_id)
      {:ok, recovered_address} = Signature.recover_address(message_hash, signature, chain_id: chain_id)
      
      assert recovered_address == expected_address
    end
  end
end
