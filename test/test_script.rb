# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require_relative '../lib/sibit/bitcoin/script'

# Sibit::Bitcoin::Script test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class TestScript < Minitest::Test
  def test_parses_p2pkh_script
    script = '76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac'
    parsed = Sibit::Bitcoin::Script.new(script)
    assert_predicate(parsed, :p2pkh?, 'script is not recognized as P2PKH')
  end

  def test_extracts_hash160_from_script
    script = '76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac'
    parsed = Sibit::Bitcoin::Script.new(script)
    assert_equal('c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa9', parsed.hash160,
                 'hash160 does not match')
  end

  def test_extracts_address_from_script
    script = '76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac'
    parsed = Sibit::Bitcoin::Script.new(script)
    assert(parsed.address.start_with?('1'), 'address does not start with 1')
  end

  def test_rejects_non_p2pkh_script
    script = 'a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa987'
    parsed = Sibit::Bitcoin::Script.new(script)
    refute_predicate(parsed, :p2pkh?, 'non-P2PKH script wrongly identified as P2PKH')
  end

  def test_returns_nil_address_for_non_p2pkh
    script = 'a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa987'
    parsed = Sibit::Bitcoin::Script.new(script)
    assert_nil(parsed.address, 'non-P2PKH should return nil address')
  end

  def test_returns_nil_hash160_for_non_p2pkh
    script = 'a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa987'
    parsed = Sibit::Bitcoin::Script.new(script)
    assert_nil(parsed.hash160, 'non-P2PKH should return nil hash160')
  end

  def test_rejects_too_short_script
    script = '76a914'
    parsed = Sibit::Bitcoin::Script.new(script)
    refute_predicate(parsed, :p2pkh?, 'too short script should not be P2PKH')
  end

  def test_rejects_wrong_op_dup
    script = '00a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac'
    parsed = Sibit::Bitcoin::Script.new(script)
    refute_predicate(parsed, :p2pkh?, 'wrong OP_DUP should not be P2PKH')
  end

  def test_rejects_wrong_op_hash160
    script = '7600c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa914088ac'
    parsed = Sibit::Bitcoin::Script.new(script)
    refute_predicate(parsed, :p2pkh?, 'wrong OP_HASH160 should not be P2PKH')
  end

  def test_rejects_wrong_hash_length
    script = '76a915c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac'
    parsed = Sibit::Bitcoin::Script.new(script)
    refute_predicate(parsed, :p2pkh?, 'wrong hash length should not be P2PKH')
  end

  def test_handles_empty_script
    parsed = Sibit::Bitcoin::Script.new('')
    refute_predicate(parsed, :p2pkh?, 'empty script should not be P2PKH')
  end
end
