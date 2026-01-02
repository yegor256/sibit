# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require 'securerandom'
require_relative '../lib/sibit/key'

# Sibit::Key test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestKey < Minitest::Test
  def test_generates_random_key
    key = Sibit::Key.generate
    assert_match(/^[0-9a-f]{64}$/, key.priv, 'private key format is wrong')
  end

  def test_creates_key_from_private
    pvt = 'fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2'
    key = Sibit::Key.new(pvt)
    assert_equal(pvt, key.priv, 'private key does not match')
  end

  def test_derives_correct_segwit_address
    pvt = 'fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2'
    key = Sibit::Key.new(pvt)
    assert_equal('bc1qcj9pwdant20em83mvf9fzrc7ytm7szau5ysh9x', key.addr, 'segwit address mismatch')
  end

  def test_signs_and_verifies
    key = Sibit::Key.generate
    data = SecureRandom.random_bytes(32)
    sig = key.sign(data)
    assert(key.verify(data, sig), 'signature verification failed')
  end

  def test_returns_compressed_public_key
    key = Sibit::Key.generate
    assert_match(/^0[23][0-9a-f]{64}$/, key.pub, 'public key format is wrong')
  end

  def test_rejects_invalid_private_key_zero
    assert_raises(RuntimeError) { Sibit::Key.new('00' * 32) }
  end

  def test_rejects_private_key_above_curve_order
    above = 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
    assert_raises(RuntimeError) { Sibit::Key.new(above) }
  end

  def test_verify_returns_false_for_invalid_signature
    key = Sibit::Key.generate
    data = SecureRandom.random_bytes(32)
    invalid = 'not a valid signature'
    refute(key.verify(data, invalid), 'invalid signature should not verify')
  end

  def test_verify_returns_false_for_wrong_data
    key = Sibit::Key.generate
    data = SecureRandom.random_bytes(32)
    sig = key.sign(data)
    wrong = SecureRandom.random_bytes(32)
    refute(key.verify(wrong, sig), 'signature verified against wrong data')
  end

  def test_generates_unique_keys
    first = Sibit::Key.generate
    second = Sibit::Key.generate
    refute_equal(first.priv, second.priv, 'generated keys are not unique')
  end

  def test_segwit_address_starts_with_bc1q
    key = Sibit::Key.generate
    assert(key.addr.start_with?('bc1q'), 'mainnet P2WPKH address must start with bc1q')
  end

  def test_public_key_length_is_sixty_six
    key = Sibit::Key.generate
    assert_equal(66, key.pub.length, 'compressed pubkey should be 66 hex chars')
  end

  def test_regtest_address_starts_with_bcrt1q
    key = Sibit::Key.generate(network: :regtest)
    assert(key.addr.start_with?('bcrt1q'), 'regtest P2WPKH address must start with bcrt1q')
  end

  def test_network_override_from_wif
    pvt = 'fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2'
    key = Sibit::Key.new(pvt, network: :regtest)
    assert_equal(:regtest, key.network, 'network override not applied')
    assert(key.addr.start_with?('bcrt1q'), 'regtest address must start with bcrt1q')
  end
end
