defmodule P2PMonitor.Crypto.KeccakTest do
  use ExUnit.Case, async: true
  
  alias P2PMonitor.Crypto.Keccak
  import P2PMonitor.Factory

  doctest P2PMonitor.Crypto.Keccak

  describe "hash/1" do
    test "produces correct hash for known inputs" do
      test_vectors = known_keccak_test_vectors()
      
      Enum.each(test_vectors, fn {input, expected_hash} ->
        assert Keccak.hash(input) == expected_hash
      end)
    end

    test "returns 32 bytes for any input" do
      inputs = ["", "a", "hello", "test data", String.duplicate("x", 1000)]
      
      Enum.each(inputs, fn input ->
        hash = Keccak.hash(input)
        assert byte_size(hash) == 32
      end)
    end

    test "produces different hashes for different inputs" do
      hash1 = Keccak.hash("hello")
      hash2 = Keccak.hash("world")
      
      assert hash1 != hash2
    end

    test "produces same hash for same input (deterministic)" do
      input = "test"
      hash1 = Keccak.hash(input)
      hash2 = Keccak.hash(input)
      
      assert hash1 == hash2
    end

    test "handles binary data" do
      binary_data = <<1, 2, 3, 4, 5>>
      hash = Keccak.hash(binary_data)
      
      assert byte_size(hash) == 32
    end

    test "handles large inputs" do
      large_input = String.duplicate("a", 100_000)
      hash = Keccak.hash(large_input)
      
      assert byte_size(hash) == 32
    end
  end

  describe "hash_hex/2" do
    test "returns hex string without prefix by default" do
      hex = Keccak.hash_hex("hello")
      
      assert is_binary(hex)
      assert String.length(hex) == 64
      assert hex == "1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8"
    end

    test "returns hex string with 0x prefix when requested" do
      hex = Keccak.hash_hex("hello", prefix: true)
      
      assert String.starts_with?(hex, "0x")
      assert String.length(hex) == 66
      assert hex == "0x1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8"
    end

    test "produces lowercase hex by default" do
      hex = Keccak.hash_hex("test")
      
      assert hex == String.downcase(hex)
    end

    test "hex can be converted back to binary" do
      original_hash = Keccak.hash("test")
      hex = Keccak.hash_hex("test")
      decoded = Base.decode16!(hex, case: :lower)
      
      assert decoded == original_hash
    end
  end

  describe "public_key_to_address/1" do
    test "converts 64-byte public key to 20-byte address" do
      public_key = :crypto.strong_rand_bytes(64)
      address = Keccak.public_key_to_address(public_key)
      
      assert byte_size(address) == 20
    end

    test "handles public key with 0x04 prefix" do
      public_key = :crypto.strong_rand_bytes(64)
      public_key_with_prefix = <<0x04>> <> public_key
      
      address1 = Keccak.public_key_to_address(public_key)
      address2 = Keccak.public_key_to_address(public_key_with_prefix)
      
      assert address1 == address2
    end

    test "produces deterministic address for same public key" do
      public_key = :crypto.strong_rand_bytes(64)
      
      address1 = Keccak.public_key_to_address(public_key)
      address2 = Keccak.public_key_to_address(public_key)
      
      assert address1 == address2
    end

    test "produces different addresses for different public keys" do
      public_key1 = :crypto.strong_rand_bytes(64)
      public_key2 = :crypto.strong_rand_bytes(64)
      
      address1 = Keccak.public_key_to_address(public_key1)
      address2 = Keccak.public_key_to_address(public_key2)
      
      assert address1 != address2
    end

    test "derives correct address for known public key" do
      # Known test case: Ethereum genesis block miner
      # Public key derived from private key 0x1
      public_key = <<
        0x79, 0xBE, 0x66, 0x7E, 0xF9, 0xDC, 0xBB, 0xAC,
        0x55, 0xA0, 0x62, 0x95, 0xCE, 0x87, 0x0B, 0x07,
        0x02, 0x9B, 0xFC, 0xDB, 0x2D, 0xCE, 0x28, 0xD9,
        0x59, 0xF2, 0x81, 0x5B, 0x16, 0xF8, 0x17, 0x98,
        0x48, 0x3A, 0xDA, 0x77, 0x26, 0xA3, 0xC4, 0x65,
        0x5D, 0xA4, 0xFB, 0xFC, 0x0E, 0x11, 0x08, 0xA8,
        0xFD, 0x17, 0xB4, 0x48, 0xA6, 0x85, 0x54, 0x19,
        0x9C, 0x47, 0xD0, 0x8F, 0xFB, 0x10, 0xD4, 0xB8
      >>
      
      expected_address = <<
        0x7E, 0x5F, 0x45, 0x52, 0x09, 0x1A, 0x69, 0x12,
        0x5D, 0x5D, 0xFC, 0xB7, 0xB8, 0xC2, 0x65, 0x90,
        0x29, 0x39, 0x5B, 0xDF
      >>
      
      assert Keccak.public_key_to_address(public_key) == expected_address
    end
  end

  describe "public_key_to_address_hex/2" do
    test "returns 40-character hex string by default" do
      public_key = :crypto.strong_rand_bytes(64)
      hex = Keccak.public_key_to_address_hex(public_key)
      
      assert String.length(hex) == 40
    end

    test "returns hex with 0x prefix when requested" do
      public_key = :crypto.strong_rand_bytes(64)
      hex = Keccak.public_key_to_address_hex(public_key, prefix: true)
      
      assert String.starts_with?(hex, "0x")
      assert String.length(hex) == 42
    end

    test "applies checksum when requested" do
      public_key = :crypto.strong_rand_bytes(64)
      hex_no_checksum = Keccak.public_key_to_address_hex(public_key, checksum: false)
      hex_checksum = Keccak.public_key_to_address_hex(public_key, checksum: true)
      
      # Checksum version should have mixed case
      assert String.downcase(hex_checksum) == hex_no_checksum
      # At least some characters should be uppercase (probabilistically)
      assert hex_checksum =~ ~r/[A-F]/
    end
  end

  describe "checksum_address/1" do
    test "applies EIP-55 checksum encoding" do
      # Known test vector from EIP-55
      address = "5aaeb6053f3e94c9b9a09f33669435e7ef1beaed"
      expected = "5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"
      
      assert Keccak.checksum_address(address) == expected
    end

    test "handles address with 0x prefix" do
      address_with_prefix = "0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed"
      expected = "5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"
      
      assert Keccak.checksum_address(address_with_prefix) == expected
    end

    test "is deterministic" do
      address = "abcdef0123456789abcdef0123456789abcdef01"
      
      checksum1 = Keccak.checksum_address(address)
      checksum2 = Keccak.checksum_address(address)
      
      assert checksum1 == checksum2
    end

    test "produces mixed case output" do
      # Use an address with letters so checksum can produce mixed case
      address = "abcdef0123456789abcdef0123456789abcdef01"
      checksummed = Keccak.checksum_address(address)
      
      # Should have at least some variation (not all same case)
      # Note: all-numeric addresses will remain lowercase
      refute checksummed == String.upcase(checksummed)
      refute checksummed == String.downcase(checksummed)
    end

    test "preserves address length" do
      address = "1234567890123456789012345678901234567890"
      checksummed = Keccak.checksum_address(address)
      
      assert String.length(checksummed) == String.length(address)
    end
  end

  describe "valid_checksum?/1" do
    test "validates correct checksum" do
      # Known valid checksum from EIP-55
      valid_address = "5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"
      
      assert Keccak.valid_checksum?(valid_address)
    end

    test "rejects incorrect checksum" do
      # Wrong case for some characters
      invalid_address = "5AAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"
      
      refute Keccak.valid_checksum?(invalid_address)
    end

    test "accepts all lowercase (no checksum)" do
      address = "5aaeb6053f3e94c9b9a09f33669435e7ef1beaed"
      
      assert Keccak.valid_checksum?(address)
    end

    test "accepts all uppercase (no checksum)" do
      address = "5AAEB6053F3E94C9B9A09F33669435E7EF1BEAED"
      
      assert Keccak.valid_checksum?(address)
    end

    test "handles address with 0x prefix" do
      valid_address = "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"
      
      assert Keccak.valid_checksum?(valid_address)
    end

    test "validates checksummed address matches" do
      original = "5aaeb6053f3e94c9b9a09f33669435e7ef1beaed"
      checksummed = Keccak.checksum_address(original)
      
      assert Keccak.valid_checksum?(checksummed)
    end

    test "multiple known valid addresses from EIP-55" do
      valid_addresses = [
        "5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
        "fB6916095ca1df60bB79Ce92cE3Ea74c37c5d359",
        "dbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB",
        "D1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb"
      ]

      Enum.each(valid_addresses, fn address ->
        assert Keccak.valid_checksum?(address)
      end)
    end
  end
end
