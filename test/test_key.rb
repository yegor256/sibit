# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require 'digest'
require 'securerandom'
require_relative '../lib/sibit/key'
require_relative '../lib/sibit/base58'

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

  def test_derives_correct_base58_address
    pvt = 'fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2'
    key = Sibit::Key.new(pvt)
    assert_equal('1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi', key.base58, 'base58 address mismatch')
  end

  def test_derives_correct_bech32_address
    pvt = 'fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2'
    key = Sibit::Key.new(pvt)
    assert_equal('bc1qcj9pwdant20em83mvf9fzrc7ytm7szau5ysh9x', key.bech32)
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

  def test_bech32_address_starts_with_bc1q
    key = Sibit::Key.generate
    assert(key.bech32.start_with?('bc1q'), 'mainnet bech32 address must start with bc1q')
  end

  def test_base58_address_starts_with_one
    key = Sibit::Key.generate
    assert(key.base58.start_with?('1'), 'mainnet base58 address must start with 1')
  end

  def test_public_key_length_is_sixty_six
    key = Sibit::Key.generate
    assert_equal(66, key.pub.length, 'compressed pubkey should be 66 hex chars')
  end

  def test_regtest_bech32_starts_with_bcrt1q
    key = Sibit::Key.generate(network: :regtest)
    assert(key.bech32.start_with?('bcrt1q'), 'regtest bech32 address must start with bcrt1q')
  end

  def test_network_override_from_wif
    pvt = 'fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2'
    key = Sibit::Key.new(pvt, network: :regtest)
    assert_equal(:regtest, key.network, 'network override not applied')
    assert(key.bech32.start_with?('bcrt1q'), 'regtest bech32 must start with bcrt1q')
  end

  def test_imports_wif_mainnet_compressed
    wif = 'KwdMAjGmerYanjeui5SHS7JkmpZvVipYvB2LJGU1ZxJwYvP98617'
    pvt = '0c28fca386c7a227600b2fe50b7cae11ec86d3bf1fbe471be89827e19d72aa1d'
    key = Sibit::Key.new(wif)
    assert_equal(pvt, key.priv, 'WIF decode produced wrong private key')
    assert_equal(:mainnet, key.network, 'WIF should detect mainnet')
  end

  def test_imports_wif_mainnet_uncompressed
    wif = '5HueCGU8rMjxEXxiPuD5BDku4MkFqeZyd4dZ1jvhTVqvbTLvyTJ'
    pvt = '0c28fca386c7a227600b2fe50b7cae11ec86d3bf1fbe471be89827e19d72aa1d'
    key = Sibit::Key.new(wif)
    assert_equal(pvt, key.priv, 'uncompressed WIF decode produced wrong key')
    assert_equal(:mainnet, key.network, 'uncompressed WIF should detect mainnet')
  end

  def test_imports_wif_testnet_compressed
    wif = 'cMzLdeGd5vEqxB8B6VFQoRopQ3sLAAvEzDAoQgvX54xwofSWj1fx'
    pvt = '0c28fca386c7a227600b2fe50b7cae11ec86d3bf1fbe471be89827e19d72aa1d'
    key = Sibit::Key.new(wif)
    assert_equal(pvt, key.priv, 'testnet WIF decode produced wrong key')
    assert_equal(:testnet, key.network, 'testnet WIF should detect testnet')
  end

  def test_imports_wif_testnet_uncompressed
    wif = '91gGn1HgSap6CbU12F6z3pJri26xzp7Ay1VW6NHCoEayNXwRpu2'
    pvt = '0c28fca386c7a227600b2fe50b7cae11ec86d3bf1fbe471be89827e19d72aa1d'
    key = Sibit::Key.new(wif)
    assert_equal(pvt, key.priv, 'testnet uncompressed WIF produced wrong key')
    assert_equal(:testnet, key.network, 'testnet uncompressed WIF should detect testnet')
  end

  def test_wif_and_hex_produce_same_address
    wif = 'KwdMAjGmerYanjeui5SHS7JkmpZvVipYvB2LJGU1ZxJwYvP98617'
    pvt = '0c28fca386c7a227600b2fe50b7cae11ec86d3bf1fbe471be89827e19d72aa1d'
    from_wif = Sibit::Key.new(wif)
    from_hex = Sibit::Key.new(pvt)
    assert_equal(from_hex.bech32, from_wif.bech32, 'WIF and hex must produce same address')
  end

  def test_accepts_uppercase_hex
    pvt = 'FD2333686F49D8647E1CE8D5EF39C304520B08F3C756B67068B30A3DB217DCB2'
    key = Sibit::Key.new(pvt)
    refute_nil(key.bech32, 'uppercase hex must be accepted')
    assert(key.bech32.start_with?('bc1q'), 'uppercase hex must produce valid address')
  end

  def test_uppercase_and_lowercase_produce_same_key
    upper = 'FD2333686F49D8647E1CE8D5EF39C304520B08F3C756B67068B30A3DB217DCB2'
    lower = 'fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2'
    from_upper = Sibit::Key.new(upper)
    from_lower = Sibit::Key.new(lower)
    assert_equal(from_lower.bech32, from_upper.bech32, 'case must not affect address')
  end

  def test_generated_key_survives_roundtrip
    original = Sibit::Key.generate
    restored = Sibit::Key.new(original.priv)
    assert_equal(original.priv, restored.priv, 'private key must survive roundtrip')
    assert_equal(original.pub, restored.pub, 'public key must survive roundtrip')
    assert_equal(original.bech32, restored.bech32, 'address must survive roundtrip')
  end

  def test_accepts_minimum_private_key
    min = '0000000000000000000000000000000000000000000000000000000000000001'
    key = Sibit::Key.new(min)
    refute_nil(key.bech32, 'minimum private key must be accepted')
  end

  def test_accepts_maximum_private_key
    max = 'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140'
    key = Sibit::Key.new(max)
    refute_nil(key.bech32, 'maximum private key must be accepted')
  end

  def test_rejects_curve_order
    order = 'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141'
    assert_raises(RuntimeError) { Sibit::Key.new(order) }
  end

  def test_rejects_above_curve_order
    above = 'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364142'
    assert_raises(RuntimeError) { Sibit::Key.new(above) }
  end

  def test_rejects_wif_with_invalid_checksum
    valid = 'KwdMAjGmerYanjeui5SHS7JkmpZvVipYvB2LJGU1ZxJwYvP98617'
    corrupted = valid[0..-2] + (valid[-1] == 'a' ? 'b' : 'a')
    assert_raises(Sibit::Error) { Sibit::Key.new(corrupted) }
  end

  def test_rejects_wif_with_invalid_version
    pvt = '0c28fca386c7a227600b2fe50b7cae11ec86d3bf1fbe471be89827e19d72aa1d'
    data = "99#{pvt}01"
    checksum = Digest::SHA256.hexdigest(Digest::SHA256.digest([data].pack('H*')))[0...8]
    invalid = Sibit::Base58.new(data + checksum).encode
    assert_raises(Sibit::Error) { Sibit::Key.new(invalid) }
  end
end
