defmodule P2PMonitor.RLP.EncoderTest do
  use ExUnit.Case, async: true
  
  alias P2PMonitor.RLP.Encoder
  import P2PMonitor.Factory

  doctest P2PMonitor.RLP.Encoder

  describe "encode/1" do
    test "encodes known test vectors correctly" do
      test_vectors = known_rlp_test_vectors()
      
      Enum.each(test_vectors, fn {input, expected_rlp} ->
        assert Encoder.encode(input) == expected_rlp
      end)
    end

    test "encodes empty string" do
      assert Encoder.encode("") == <<0x80>>
      assert Encoder.encode(<<>>) == <<0x80>>
    end

    test "encodes single byte less than 0x80" do
      assert Encoder.encode(<<0x00>>) == <<0x00>>
      assert Encoder.encode(<<0x01>>) == <<0x01>>
      assert Encoder.encode(<<0x7F>>) == <<0x7F>>
    end

    test "encodes short strings (< 56 bytes)" do
      # "dog" = 0x646F67
      assert Encoder.encode("dog") == <<0x83, 0x64, 0x6F, 0x67>>
      
      # Short string
      assert Encoder.encode("hello") == <<0x85>> <> "hello"
    end

    test "encodes long strings (>= 56 bytes)" do
      # String of 56 bytes
      long_string = String.duplicate("a", 56)
      encoded = Encoder.encode(long_string)
      
      # Should start with 0xB8 (0x80 + 0x38) for 56 bytes
      assert <<0xB8, 0x38, rest::binary>> = encoded
      assert rest == long_string
    end

    test "encodes very long strings" do
      # String of 1000 bytes
      very_long_string = String.duplicate("x", 1000)
      encoded = Encoder.encode(very_long_string)
      
      # Verify it's properly encoded
      assert byte_size(encoded) > byte_size(very_long_string)
      assert String.contains?(encoded, very_long_string)
    end

    test "encodes empty list" do
      assert Encoder.encode([]) == <<0xC0>>
    end

    test "encodes list with single element" do
      assert Encoder.encode([""]) == <<0xC1, 0x80>>
      assert Encoder.encode([<<0x01>>]) == <<0xC1, 0x01>>
    end

    test "encodes list with multiple elements" do
      # ["cat", "dog"]
      expected = <<0xC8, 0x83, 0x63, 0x61, 0x74, 0x83, 0x64, 0x6F, 0x67>>
      assert Encoder.encode(["cat", "dog"]) == expected
    end

    test "encodes nested lists" do
      # [[], [[]]]
      # C3 = list of 3 bytes, C0 = empty list, C1 = list of 1 byte, C0 = empty list
      assert Encoder.encode([[], [[]]]) == <<0xC3, 0xC0, 0xC1, 0xC0>>
    end

    test "encodes integer 0 as empty string" do
      assert Encoder.encode(0) == <<0x80>>
    end

    test "encodes small positive integers" do
      assert Encoder.encode(1) == <<0x01>>
      assert Encoder.encode(127) == <<0x7F>>
      assert Encoder.encode(128) == <<0x81, 0x80>>
      assert Encoder.encode(255) == <<0x81, 0xFF>>
    end

    test "encodes larger integers" do
      assert Encoder.encode(1000) == <<0x82, 0x03, 0xE8>>
      assert Encoder.encode(100000) == <<0x83, 0x01, 0x86, 0xA0>>
    end

    test "encodes very large integers (256-bit)" do
      large_int = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      encoded = Encoder.encode(large_int)
      
      # Should encode to 32 bytes of 0xFF
      assert byte_size(encoded) >= 32
    end

    test "encodes nil as empty string" do
      assert Encoder.encode(nil) == <<0x80>>
    end

    test "encodes binary data" do
      binary = <<0xDE, 0xAD, 0xBE, 0xEF>>
      encoded = Encoder.encode(binary)
      
      assert <<0x84, 0xDE, 0xAD, 0xBE, 0xEF>> == encoded
    end

    test "encodes mixed list" do
      # ["hello", 42, "world"]
      encoded = Encoder.encode(["hello", 42, "world"])
      
      assert is_binary(encoded)
      assert byte_size(encoded) > 0
    end
  end

  describe "encode_transaction/1" do
    test "encodes legacy transaction without signature" do
      tx = %{
        type: :legacy,
        nonce: 0,
        gas_price: 20_000_000_000,
        gas_limit: 21_000,
        to: <<0x12, 0x34>>,
        value: 1_000_000_000_000_000_000,
        data: <<>>
      }
      
      encoded = Encoder.encode_transaction(tx)
      
      assert is_binary(encoded)
      assert byte_size(encoded) > 0
    end

    test "encodes legacy transaction with signature" do
      tx = %{
        type: :legacy,
        nonce: 9,
        gas_price: 20_000_000_000,
        gas_limit: 21_000,
        to: <<0x3535353535353535353535353535353535353535::160>>,
        value: 1_000_000_000_000_000_000,
        data: <<>>,
        v: 27,
        r: 0x28ef61340bd939bc2195fe537567866003e1a15d3c71ff63e1590620aa636276,
        s: 0x67cbe9d8997f761aecb703304b3800ccf555c9f3dc64214b297fb1966a3b6d83
      }
      
      encoded = Encoder.encode_transaction(tx)
      
      assert is_binary(encoded)
      assert byte_size(encoded) > 0
    end

    test "encodes minimal transaction" do
      tx = build_minimal_transaction()
      encoded = Encoder.encode_transaction(tx)
      
      assert is_binary(encoded)
      assert byte_size(encoded) > 0
    end

    test "encodes transaction without type field (defaults to legacy)" do
      tx = %{
        nonce: 0,
        gas_price: 1,
        gas_limit: 21000,
        to: <<>>,
        value: 0,
        data: <<>>
      }
      
      encoded = Encoder.encode_transaction(tx)
      
      assert is_binary(encoded)
    end

    test "encodes EIP-1559 transaction" do
      tx = %{
        type: :eip1559,
        chain_id: 1,
        nonce: 0,
        max_priority_fee_per_gas: 2_000_000_000,
        max_fee_per_gas: 30_000_000_000,
        gas_limit: 21_000,
        to: <<0x12, 0x34>>,
        value: 1_000_000_000_000_000_000,
        data: <<>>,
        access_list: []
      }
      
      encoded = Encoder.encode_transaction(tx)
      
      # EIP-1559 should start with 0x02
      assert <<0x02, _rest::binary>> = encoded
    end

    test "encodes EIP-1559 transaction with signature" do
      tx = %{
        type: :eip1559,
        chain_id: 1,
        nonce: 0,
        max_priority_fee_per_gas: 2_000_000_000,
        max_fee_per_gas: 30_000_000_000,
        gas_limit: 21_000,
        to: <<0x12, 0x34>>,
        value: 1_000_000_000_000_000_000,
        data: <<>>,
        access_list: [],
        v: 1,
        r: 0x1234,
        s: 0x5678
      }
      
      encoded = Encoder.encode_transaction(tx)
      
      assert <<0x02, _rest::binary>> = encoded
    end

    test "encodes EIP-2930 transaction" do
      tx = %{
        type: :eip2930,
        chain_id: 1,
        nonce: 0,
        gas_price: 20_000_000_000,
        gas_limit: 21_000,
        to: <<0x12, 0x34>>,
        value: 1_000_000_000_000_000_000,
        data: <<>>,
        access_list: []
      }
      
      encoded = Encoder.encode_transaction(tx)
      
      # EIP-2930 should start with 0x01
      assert <<0x01, _rest::binary>> = encoded
    end

    test "encodes transaction with contract creation (empty to)" do
      tx = %{
        type: :legacy,
        nonce: 0,
        gas_price: 20_000_000_000,
        gas_limit: 100_000,
        to: <<>>,
        value: 0,
        data: <<0x60, 0x60, 0x60>>  # Some bytecode
      }
      
      encoded = Encoder.encode_transaction(tx)
      
      assert is_binary(encoded)
    end

    test "encodes transaction with data" do
      tx = %{
        type: :legacy,
        nonce: 0,
        gas_price: 20_000_000_000,
        gas_limit: 50_000,
        to: <<0x12, 0x34>>,
        value: 0,
        data: <<0xAB, 0xCD, 0xEF>>
      }
      
      encoded = Encoder.encode_transaction(tx)
      
      assert is_binary(encoded)
      # Data should be included
      assert String.contains?(encoded, <<0xAB, 0xCD, 0xEF>>)
    end

    test "handles transaction with gas alias" do
      tx = %{
        nonce: 0,
        gas_price: 1,
        gas: 21000,  # Using 'gas' instead of 'gas_limit'
        to: <<>>,
        value: 0,
        data: <<>>
      }
      
      encoded = Encoder.encode_transaction(tx)
      
      assert is_binary(encoded)
    end

    test "handles transaction with input alias" do
      tx = %{
        nonce: 0,
        gas_price: 1,
        gas_limit: 21000,
        to: <<>>,
        value: 0,
        input: <<0x12, 0x34>>  # Using 'input' instead of 'data'
      }
      
      encoded = Encoder.encode_transaction(tx)
      
      assert is_binary(encoded)
    end

    test "encodes transaction from factory" do
      tx = build_legacy_transaction()
      encoded = Encoder.encode_transaction(tx)
      
      assert is_binary(encoded)
    end

    test "encodes EIP-1559 transaction from factory" do
      tx = build_eip1559_transaction()
      encoded = Encoder.encode_transaction(tx)
      
      assert <<0x02, _rest::binary>> = encoded
    end

    test "encodes EIP-2930 transaction from factory" do
      tx = build_eip2930_transaction()
      encoded = Encoder.encode_transaction(tx)
      
      assert <<0x01, _rest::binary>> = encoded
    end
  end

  describe "encoding edge cases" do
    test "encodes list with empty strings" do
      encoded = Encoder.encode(["", "", ""])
      
      assert is_binary(encoded)
      assert byte_size(encoded) > 0
    end

    test "encodes deeply nested lists" do
      nested = [[[[[]]]]]
      encoded = Encoder.encode(nested)
      
      assert is_binary(encoded)
    end

    test "encodes list with various types" do
      mixed = ["string", 42, <<0xAB>>, [], 0]
      encoded = Encoder.encode(mixed)
      
      assert is_binary(encoded)
    end

    test "handles large transaction values" do
      tx = %{
        type: :legacy,
        nonce: 0,
        gas_price: 1,
        gas_limit: 21000,
        to: <<0x12, 0x34>>,
        value: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,  # Very large value
        data: <<>>
      }
      
      encoded = Encoder.encode_transaction(tx)
      
      assert is_binary(encoded)
    end

    test "handles high nonce values" do
      tx = %{
        type: :legacy,
        nonce: 999_999_999,
        gas_price: 1,
        gas_limit: 21000,
        to: <<0x12, 0x34>>,
        value: 0,
        data: <<>>
      }
      
      encoded = Encoder.encode_transaction(tx)
      
      assert is_binary(encoded)
    end
  end
end
