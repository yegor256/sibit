# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative '../lib/sibit/script'
require_relative 'test__helper'

# Sibit::Script test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestScript < Minitest::Test
  def test_parses_p2pkh_script
    assert_predicate(
      Sibit::Script.new('76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac'),
      :p2pkh?, 'script is not recognized as P2PKH'
    )
  end

  def test_extracts_hash160_from_script
    assert_equal(
      'c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa9', Sibit::Script.new('76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac').hash160,
      'hash160 does not match'
    )
  end

  def test_extracts_address_from_script
    assert(
      Sibit::Script.new('76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac').address.start_with?('1'),
      'address does not start with 1'
    )
  end

  def test_rejects_non_p2pkh_script
    refute_predicate(
      Sibit::Script.new('a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa987'), :p2pkh?,
      'non-P2PKH script wrongly identified as P2PKH'
    )
  end

  def test_returns_nil_address_for_non_p2pkh
    assert_nil(
      Sibit::Script.new('a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa987').address,
      'non-P2PKH should return nil address'
    )
  end

  def test_returns_nil_hash160_for_non_p2pkh
    assert_nil(
      Sibit::Script.new('a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa987').hash160,
      'non-P2PKH should return nil hash160'
    )
  end

  def test_rejects_too_short_script
    refute_predicate(Sibit::Script.new('76a914'), :p2pkh?, 'too short script should not be P2PKH')
  end

  def test_rejects_wrong_op_dup
    refute_predicate(
      Sibit::Script.new('00a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac'),
      :p2pkh?, 'wrong OP_DUP should not be P2PKH'
    )
  end

  def test_rejects_wrong_op_hash160
    refute_predicate(
      Sibit::Script.new('7600c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa914088ac'),
      :p2pkh?, 'wrong OP_HASH160 should not be P2PKH'
    )
  end

  def test_rejects_wrong_hash_length
    refute_predicate(
      Sibit::Script.new('76a915c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac'),
      :p2pkh?, 'wrong hash length should not be P2PKH'
    )
  end

  def test_handles_empty_script
    refute_predicate(Sibit::Script.new(''), :p2pkh?, 'empty script should not be P2PKH')
  end

  def test_parses_p2wpkh_script
    assert_predicate(
      Sibit::Script.new('0014c48a1737b35a9f9d9e3b624a910f1e22f7e80bbc'), :p2wpkh?,
      'script is not recognized as P2WPKH'
    )
  end

  def test_extracts_hash160_from_p2wpkh
    assert_equal(
      'c48a1737b35a9f9d9e3b624a910f1e22f7e80bbc',
      Sibit::Script.new('0014c48a1737b35a9f9d9e3b624a910f1e22f7e80bbc').hash160, 'hash160 mismatch'
    )
  end

  def test_extracts_segwit_address_from_p2wpkh
    assert(
      Sibit::Script.new('0014c48a1737b35a9f9d9e3b624a910f1e22f7e80bbc').address.start_with?('bc1q'),
      'P2WPKH address must start with bc1q'
    )
  end

  def test_rejects_wrong_witness_version
    refute_predicate(
      Sibit::Script.new('0114c48a1737b35a9f9d9e3b624a910f1e22f7e80bbc'), :p2wpkh?,
      'wrong witness version should not be P2WPKH'
    )
  end
end
