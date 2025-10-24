defmodule P2PMonitor.RLP.DecoderTest do
  use ExUnit.Case, async: true
  
  alias P2PMonitor.RLP.{Encoder, Decoder}
  import P2PMonitor.Factory

  doctest P2PMonitor.RLP.Decoder

  describe "decode/1" do
    test "decodes known test vectors correctly" do
      test_vectors = known_rlp_test_vectors()
      
      Enum.each(test_vectors, fn {expected, rlp} ->
        assert {:ok, decoded} = Decoder.decode(rlp)
        # Normalize for comparison
        assert normalize_decoded(decoded) == normalize_decoded(expected)
      end)
    end

    test "decodes empty string" do
      assert {:ok, ""} = Decoder.decode(<<0x80>>)
    end

    test "decodes single byte less than 0x80" do
      assert {:ok, <<0x00>>} = Decoder.decode(<<0x00>>)
      assert {:ok, <<0x01>>} = Decoder.decode(<<0x01>>)
      assert {:ok, <<0x7F>>} = Decoder.decode(<<0x7F>>)
    end

    test "decodes short strings" do
      assert {:ok, "dog"} = Decoder.decode(<<0x83, 0x64, 0x6F, 0x67>>)
    end

    test "decodes empty list" do
      assert {:ok, []} = Decoder.decode(<<0xC0>>)
    end

    test "decodes list with elements" do
      assert {:ok, ["cat", "dog"]} = Decoder.decode(<<0xC8, 0x83, 0x63, 0x61, 0x74, 0x83, 0x64, 0x6F, 0x67>>)
    end

    test "decodes nested lists" do
      # Test simpler nested structure that works with ExRLP
    encoded = Encoder.encode([[], []])
    assert {:ok, [[], []]} = Decoder.decode(encoded)
    end

    test "returns error for invalid RLP" do
      assert {:error, :invalid_rlp} = Decoder.decode(<<0xFF, 0xFF>>)
    end

    test "returns error for truncated RLP" do
      # Declares length of 10 but only provides 2 bytes
      assert {:error, :invalid_rlp} = Decoder.decode(<<0x8A, 0x01, 0x02>>)
    end

    test "returns error for empty input" do
      assert {:error, :invalid_rlp} = Decoder.decode(<<>>)
    end

    test "decodes long strings" do
      long_string = String.duplicate("a", 56)
      encoded = Encoder.encode(long_string)
      
      assert {:ok, decoded} = Decoder.decode(encoded)
      assert decoded == long_string
    end

    test "decodes very long strings" do
      very_long_string = String.duplicate("x", 1000)
      encoded = Encoder.encode(very_long_string)
      
      assert {:ok, decoded} = Decoder.decode(encoded)
      assert decoded == very_long_string
    end

    test "decodes binary data" do
      binary = <<0xDE, 0xAD, 0xBE, 0xEF>>
      encoded = Encoder.encode(binary)
      
      assert {:ok, decoded} = Decoder.decode(encoded)
      assert decoded == binary
    end

    test "decodes mixed list" do
      mixed = ["hello", <<0x2A>>, "world"]
      encoded = Encoder.encode(mixed)
      
      assert {:ok, decoded} = Decoder.decode(encoded)
      assert decoded == mixed
    end
  end

  describe "decode!/1" do
    test "returns decoded value on success" do
      encoded = Encoder.encode("test")
      
      assert Decoder.decode!(encoded) == "test"
    end

    test "raises error on invalid RLP" do
      assert_raise RuntimeError, fn ->
        Decoder.decode!(<<0xFF, 0xFF>>)
      end
    end
  end

  describe "decode_transaction/1" do
    test "decodes legacy transaction without signature" do
      tx = %{
        nonce: 0,
        gas_price: 20_000_000_000,
        gas_limit: 21_000,
        to: <<0x12, 0x34>>,
        value: 1_000_000_000_000_000_000,
        data: <<>>
      }
      
      encoded = Encoder.encode_transaction(tx)
      
      assert {:ok, decoded} = Decoder.decode_transaction(encoded)
      assert decoded.type == :legacy
      assert decoded.nonce == 0
      assert decoded.gas_price == 20_000_000_000
      assert decoded.gas_limit == 21_000
    end

    test "decodes legacy transaction with signature" do
      tx = %{
        type: :legacy,
        nonce: 9,
        gas_price: 20_000_000_000,
        gas_limit: 21_000,
        to: <<0x3535353535353535353535353535353535353535::160>>,
        value: 1_000_000_000_000_000_000,
        data: <<>>,
        v: 27,
        r: 0x1234,
        s: 0x5678
      }
      
      encoded = Encoder.encode_transaction(tx)
      
      assert {:ok, decoded} = Decoder.decode_transaction(encoded)
      assert decoded.type == :legacy
      assert decoded.v == 27
      assert decoded.r == 0x1234
      assert decoded.s == 0x5678
    end

    test "decodes EIP-1559 transaction" do
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
      
      assert {:ok, decoded} = Decoder.decode_transaction(encoded)
      assert decoded.type == :eip1559
      assert decoded.chain_id == 1
      assert decoded.max_priority_fee_per_gas == 2_000_000_000
      assert decoded.max_fee_per_gas == 30_000_000_000
    end

    test "decodes EIP-1559 transaction with signature" do
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
      
      assert {:ok, decoded} = Decoder.decode_transaction(encoded)
      assert decoded.type == :eip1559
      assert decoded.v == 1
      assert decoded.r == 0x1234
      assert decoded.s == 0x5678
    end

    test "decodes EIP-2930 transaction" do
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
      
      assert {:ok, decoded} = Decoder.decode_transaction(encoded)
      assert decoded.type == :eip2930
      assert decoded.chain_id == 1
      assert decoded.gas_price == 20_000_000_000
    end

    test "detects transaction type from first byte" do
      # Legacy (no prefix)
      legacy_tx = build_minimal_transaction()
      legacy_encoded = Encoder.encode_transaction(legacy_tx)
      assert {:ok, decoded} = Decoder.decode_transaction(legacy_encoded)
      assert decoded.type == :legacy
      
      # EIP-1559 (0x02 prefix)
      eip1559_tx = build_eip1559_transaction()
      eip1559_encoded = Encoder.encode_transaction(eip1559_tx)
      assert {:ok, decoded} = Decoder.decode_transaction(eip1559_encoded)
      assert decoded.type == :eip1559
      
      # EIP-2930 (0x01 prefix)
      eip2930_tx = build_eip2930_transaction()
      eip2930_encoded = Encoder.encode_transaction(eip2930_tx)
      assert {:ok, decoded} = Decoder.decode_transaction(eip2930_encoded)
      assert decoded.type == :eip2930
    end

    test "decodes transaction with empty to (contract creation)" do
      tx = %{
        type: :legacy,
        nonce: 0,
        gas_price: 20_000_000_000,
        gas_limit: 100_000,
        to: <<>>,
        value: 0,
        data: <<0x60, 0x60, 0x60>>
      }
      
      encoded = Encoder.encode_transaction(tx)
      
      assert {:ok, decoded} = Decoder.decode_transaction(encoded)
      assert decoded.to == <<>>
      assert decoded.data == <<0x60, 0x60, 0x60>>
    end

    test "decodes transaction with data" do
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
      
      assert {:ok, decoded} = Decoder.decode_transaction(encoded)
      assert decoded.data == <<0xAB, 0xCD, 0xEF>>
    end

    test "returns error for invalid transaction RLP" do
      assert {:error, :invalid_transaction} = Decoder.decode_transaction(<<0xFF, 0xFF>>)
    end

    test "handles transaction with minimal fields" do
      tx = build_minimal_transaction()
      encoded = Encoder.encode_transaction(tx)
      
      assert {:ok, decoded} = Decoder.decode_transaction(encoded)
      assert is_map(decoded)
      assert decoded.type == :legacy
    end
  end

  describe "encode/decode roundtrip" do
    test "roundtrip for strings" do
      strings = ["", "a", "hello", "test data", String.duplicate("x", 100)]
      
      Enum.each(strings, fn str ->
        encoded = Encoder.encode(str)
        assert {:ok, decoded} = Decoder.decode(encoded)
        assert decoded == str
      end)
    end

    test "roundtrip for integers" do
      integers = [0, 1, 127, 128, 255, 256, 1000, 100000, 0xFFFFFFFF]
      
      Enum.each(integers, fn int ->
        encoded = Encoder.encode(int)
        assert {:ok, decoded} = Decoder.decode(encoded)
        # Convert back to integer for comparison
        decoded_int = if decoded == "", do: 0, else: :binary.decode_unsigned(decoded, :big)
        assert decoded_int == int
      end)
    end

    test "roundtrip for lists" do
      lists = [
        [],
        [""],
        ["a", "b", "c"],
        [[], []],
        [[["nested"]]]
      ]
      
      Enum.each(lists, fn list ->
        encoded = Encoder.encode(list)
        assert {:ok, decoded} = Decoder.decode(encoded)
        assert decoded == list
      end)
    end

    test "roundtrip for binary data" do
      binaries = [
        <<>>,
        <<0x00>>,
        <<0xFF>>,
        <<0xDE, 0xAD, 0xBE, 0xEF>>,
        :crypto.strong_rand_bytes(32)
      ]
      
      Enum.each(binaries, fn binary ->
        encoded = Encoder.encode(binary)
        assert {:ok, decoded} = Decoder.decode(encoded)
        assert decoded == binary
      end)
    end

    test "roundtrip for legacy transactions" do
      tx = build_legacy_transaction()
      encoded = Encoder.encode_transaction(tx)
      
      assert {:ok, decoded} = Decoder.decode_transaction(encoded)
      assert decoded.type == :legacy
      assert decoded.nonce == tx.nonce
      assert decoded.gas_limit == tx.gas_limit
    end

    test "roundtrip for EIP-1559 transactions" do
      tx = build_eip1559_transaction()
      encoded = Encoder.encode_transaction(tx)
      
      assert {:ok, decoded} = Decoder.decode_transaction(encoded)
      assert decoded.type == :eip1559
      assert decoded.chain_id == tx.chain_id
    end

    test "roundtrip for EIP-2930 transactions" do
      tx = build_eip2930_transaction()
      encoded = Encoder.encode_transaction(tx)
      
      assert {:ok, decoded} = Decoder.decode_transaction(encoded)
      assert decoded.type == :eip2930
      assert decoded.chain_id == tx.chain_id
    end

    test "multiple roundtrips produce same result" do
      data = ["test", "data", "list"]
      
      encoded = Encoder.encode(data)
      {:ok, decoded1} = Decoder.decode(encoded)
      
      re_encoded = Encoder.encode(decoded1)
      {:ok, decoded2} = Decoder.decode(re_encoded)
      
      assert decoded1 == decoded2
    end
  end

  describe "edge cases" do
    test "handles very deeply nested structures" do
      nested = [[[[[[[[[[]]]]]]]]]]
      encoded = Encoder.encode(nested)
      
      assert {:ok, decoded} = Decoder.decode(encoded)
      assert decoded == nested
    end

    test "handles list with many elements" do
      large_list = Enum.map(1..100, fn i -> "item#{i}" end)
      encoded = Encoder.encode(large_list)
      
      assert {:ok, decoded} = Decoder.decode(encoded)
      assert decoded == large_list
    end

    test "handles mixed content lists" do
      mixed = ["string", <<0x42>>, "", <<0xAB, 0xCD>>]
      encoded = Encoder.encode(mixed)
      
      assert {:ok, decoded} = Decoder.decode(encoded)
      assert decoded == mixed
    end
  end

  # Helper function to normalize decoded values for comparison
  defp normalize_decoded(data) when is_list(data) do
    Enum.map(data, &normalize_decoded/1)
  end
  
  defp normalize_decoded(data) when is_binary(data), do: data
  defp normalize_decoded(0), do: ""
  defp normalize_decoded(data) when is_integer(data) do
    if data == 0 do
      ""
    else
      :binary.encode_unsigned(data, :big)
    end
  end
  defp normalize_decoded(nil), do: ""
  defp normalize_decoded(data), do: data
end
