# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative '../lib/sibit/base58'
require_relative 'test__helper'

# Sibit::Base58 test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestBase58 < Minitest::Test
  def test_encodes_hex_to_base58
    assert_kind_of(
      String,
      Sibit::Base58.new('00c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa91a2b6c3d').encode,
      'encoded value is not a string'
    )
  end

  def test_decodes_base58_to_hex
    assert_match(
      /^[0-9a-f]+$/i, Sibit::Base58.new('1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi').decode,
      'decoded value is not hex'
    )
  end

  def test_computes_checksum
    assert_equal(
      8, Sibit::Base58.new('00c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa9').check.length,
      'checksum is not 8 chars'
    )
  end

  def test_roundtrip_encode_decode
    original = '00c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa91a2b6c3d'
    assert_equal(
      original, Sibit::Base58.new(Sibit::Base58.new(original).encode).decode.downcase,
      'roundtrip failed'
    )
  end

  def test_preserves_leading_zeros_on_encode
    assert(
      Sibit::Base58.new('0000ff').encode.start_with?('11'),
      'leading zeros not preserved as 1s'
    )
  end

  def test_preserves_leading_ones_on_decode
    assert(
      Sibit::Base58.new('111JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi').decode.start_with?('0000'),
      'leading 1s not decoded as 00'
    )
  end

  def test_decodes_single_digit
    assert_equal('01', Sibit::Base58.new('2').decode, 'single digit decode failed')
  end

  def test_encodes_small_number
    assert_kind_of(String, Sibit::Base58.new('3a').encode, 'small number encode failed')
  end

  def test_checksum_is_deterministic
    hex = 'deadbeef'
    assert_equal(
      Sibit::Base58.new(hex).check, Sibit::Base58.new(hex).check,
      'checksum is not deterministic'
    )
  end

  def test_different_inputs_produce_different_checksums
    refute_equal(
      Sibit::Base58.new('deadbeef').check, Sibit::Base58.new('cafebabe').check,
      'different inputs produce same checksum'
    )
  end
end
