# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require_relative '../lib/sibit/bech32'

# Sibit::Bech32 test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestBech32 < Minitest::Test
  def test_decodes_p2wpkh_address
    addr = 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4'
    bech = Sibit::Bech32.new(addr)
    assert_equal('751e76e8199196d454941c45d1b3a323f1433bd6', bech.witness, 'witness mismatch')
  end

  def test_returns_version_zero
    addr = 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4'
    bech = Sibit::Bech32.new(addr)
    assert_equal(0, bech.version, 'version must be 0 for P2WPKH')
  end

  def test_decodes_uppercase_address
    addr = 'BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3T4'
    bech = Sibit::Bech32.new(addr)
    assert_equal('751e76e8199196d454941c45d1b3a323f1433bd6', bech.witness, 'uppercase must work')
  end

  def test_rejects_invalid_checksum
    addr = 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t5'
    bech = Sibit::Bech32.new(addr)
    assert_raises(Sibit::Error) { bech.witness }
  end

  def test_rejects_missing_separator
    bech = Sibit::Bech32.new('bcqw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4')
    assert_raises(Sibit::Error) { bech.witness }
  end

  def test_rejects_invalid_character
    bech = Sibit::Bech32.new('bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3tb')
    assert_raises(Sibit::Error) { bech.witness }
  end
end
