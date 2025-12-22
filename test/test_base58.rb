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
    assert(encoded.is_a?(String), 'encoded value is not a string')
  end

  def test_decodes_base58_to_hex
    addr = '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi'
    decoded = Sibit::Bitcoin::Base58.decode(addr)
    assert(/^[0-9a-f]+$/i.match?(decoded), 'decoded value is not hex')
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
end
