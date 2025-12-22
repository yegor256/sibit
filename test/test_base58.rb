# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require_relative '../lib/sibit/bitcoin/base58'

# Sibit::Bitcoin::Base58 test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class TestBase58 < Minitest::Test
  def test_encodes_hex_to_base58
    hex = '00c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa91a2b6c3d'
    encoded = Sibit::Bitcoin::Base58.encode(hex)
    assert_kind_of(String, encoded, 'encoded value is not a string')
  end

  def test_decodes_base58_to_hex
    addr = '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi'
    decoded = Sibit::Bitcoin::Base58.decode(addr)
    assert_match(/^[0-9a-f]+$/i, decoded, 'decoded value is not hex')
  end

  def test_computes_checksum
    hex = '00c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa9'
    checksum = Sibit::Bitcoin::Base58.check(hex)
    assert_equal(8, checksum.length, 'checksum is not 8 chars')
  end

  def test_roundtrip_encode_decode
    original = '00c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa91a2b6c3d'
    encoded = Sibit::Bitcoin::Base58.encode(original)
    decoded = Sibit::Bitcoin::Base58.decode(encoded)
    assert_equal(original, decoded.downcase, 'roundtrip failed')
  end

  def test_preserves_leading_zeros_on_encode
    hex = '0000ff'
    encoded = Sibit::Bitcoin::Base58.encode(hex)
    assert(encoded.start_with?('11'), 'leading zeros not preserved as 1s')
  end

  def test_preserves_leading_ones_on_decode
    addr = '111JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi'
    decoded = Sibit::Bitcoin::Base58.decode(addr)
    assert(decoded.start_with?('0000'), 'leading 1s not decoded as 00')
  end

  def test_decodes_single_digit
    decoded = Sibit::Bitcoin::Base58.decode('2')
    assert_equal('01', decoded, 'single digit decode failed')
  end

  def test_encodes_small_number
    encoded = Sibit::Bitcoin::Base58.encode('3a')
    assert_kind_of(String, encoded, 'small number encode failed')
  end

  def test_checksum_is_deterministic
    hex = 'deadbeef'
    first = Sibit::Bitcoin::Base58.check(hex)
    second = Sibit::Bitcoin::Base58.check(hex)
    assert_equal(first, second, 'checksum is not deterministic')
  end

  def test_different_inputs_produce_different_checksums
    first = Sibit::Bitcoin::Base58.check('deadbeef')
    second = Sibit::Bitcoin::Base58.check('cafebabe')
    refute_equal(first, second, 'different inputs produce same checksum')
  end
end
