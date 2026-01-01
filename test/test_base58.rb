# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require_relative '../lib/sibit/base58'

# Sibit::Base58 test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestBase58 < Minitest::Test
  def test_encodes_hex_to_base58
    hex = '00c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa91a2b6c3d'
    encoded = Sibit::Base58.new(hex).encode
    assert_kind_of(String, encoded, 'encoded value is not a string')
  end

  def test_decodes_base58_to_hex
    addr = '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi'
    decoded = Sibit::Base58.new(addr).decode
    assert_match(/^[0-9a-f]+$/i, decoded, 'decoded value is not hex')
  end

  def test_computes_checksum
    hex = '00c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa9'
    checksum = Sibit::Base58.new(hex).check
    assert_equal(8, checksum.length, 'checksum is not 8 chars')
  end

  def test_roundtrip_encode_decode
    original = '00c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa91a2b6c3d'
    encoded = Sibit::Base58.new(original).encode
    decoded = Sibit::Base58.new(encoded).decode
    assert_equal(original, decoded.downcase, 'roundtrip failed')
  end

  def test_preserves_leading_zeros_on_encode
    hex = '0000ff'
    encoded = Sibit::Base58.new(hex).encode
    assert(encoded.start_with?('11'), 'leading zeros not preserved as 1s')
  end

  def test_preserves_leading_ones_on_decode
    addr = '111JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi'
    decoded = Sibit::Base58.new(addr).decode
    assert(decoded.start_with?('0000'), 'leading 1s not decoded as 00')
  end

  def test_decodes_single_digit
    decoded = Sibit::Base58.new('2').decode
    assert_equal('01', decoded, 'single digit decode failed')
  end

  def test_encodes_small_number
    encoded = Sibit::Base58.new('3a').encode
    assert_kind_of(String, encoded, 'small number encode failed')
  end

  def test_checksum_is_deterministic
    hex = 'deadbeef'
    first = Sibit::Base58.new(hex).check
    second = Sibit::Base58.new(hex).check
    assert_equal(first, second, 'checksum is not deterministic')
  end

  def test_different_inputs_produce_different_checksums
    first = Sibit::Base58.new('deadbeef').check
    second = Sibit::Base58.new('cafebabe').check
    refute_equal(first, second, 'different inputs produce same checksum')
  end
end
