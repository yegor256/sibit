# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require 'digest'
require 'securerandom'
require_relative '../lib/sibit/base58'
require_relative '../lib/sibit/key'

# Sibit::Key test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestKey < Minitest::Test
  def test_generates_random_key
    assert_match(/^[0-9a-f]{64}$/, Sibit::Key.generate.priv, 'private key format is wrong')
  end

  def test_creates_key_from_private
    pvt = 'fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2'
    assert_equal(pvt, Sibit::Key.new(pvt).priv, 'private key does not match')
  end

  def test_derives_correct_base58_address
    assert_equal(
      '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi',
      Sibit::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2').base58,
      'base58 address mismatch'
    )
  end

  def test_derives_correct_bech32_address
    assert_equal('bc1qcj9pwdant20em83mvf9fzrc7ytm7szau5ysh9x', Sibit::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2').bech32)
  end

  def test_signs_and_verifies
    key = Sibit::Key.generate
    data = SecureRandom.random_bytes(32)
    assert(key.verify(data, key.sign(data)), 'signature verification failed')
  end

  def test_returns_compressed_public_key
    assert_match(/^0[23][0-9a-f]{64}$/, Sibit::Key.generate.pub, 'public key format is wrong')
  end

  def test_rejects_invalid_private_key_zero
    assert_raises(Sibit::Error) { Sibit::Key.new('00' * 32) }
  end

  def test_rejects_private_key_above_curve_order
    above = 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
    assert_raises(Sibit::Error) { Sibit::Key.new(above) }
  end

  def test_verify_returns_false_for_invalid_signature
    refute(
      Sibit::Key.generate.verify(SecureRandom.random_bytes(32), 'not a valid signature'),
      'invalid signature should not verify'
    )
  end

  def test_verify_returns_false_for_wrong_data
    key = Sibit::Key.generate
    refute(
      key.verify(SecureRandom.random_bytes(32), key.sign(SecureRandom.random_bytes(32))),
      'signature verified against wrong data'
    )
  end

  def test_generates_unique_keys
    refute_equal(
      Sibit::Key.generate.priv, Sibit::Key.generate.priv,
      'generated keys are not unique'
    )
  end

  def test_bech32_address_starts_with_bc1q
    assert(
      Sibit::Key.generate.bech32.start_with?('bc1q'),
      'mainnet bech32 address must start with bc1q'
    )
  end

  def test_base58_address_starts_with_one
    assert(Sibit::Key.generate.base58.start_with?('1'), 'mainnet base58 address must start with 1')
  end

  def test_public_key_length_is_sixty_six
    assert_equal(66, Sibit::Key.generate.pub.length, 'compressed pubkey should be 66 hex chars')
  end

  def test_regtest_bech32_starts_with_bcrt1q
    assert(
      Sibit::Key.generate(network: :regtest).bech32.start_with?('bcrt1q'),
      'regtest bech32 address must start with bcrt1q'
    )
  end

  def test_network_override_from_wif
    key = Sibit::Key.new(
      'fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2',
      network: :regtest
    )
    assert_equal(:regtest, key.network, 'network override not applied')
    assert(key.bech32.start_with?('bcrt1q'), 'regtest bech32 must start with bcrt1q')
  end

  def test_imports_wif_mainnet_compressed
    key = Sibit::Key.new('KwdMAjGmerYanjeui5SHS7JkmpZvVipYvB2LJGU1ZxJwYvP98617')
    assert_equal(
      '0c28fca386c7a227600b2fe50b7cae11ec86d3bf1fbe471be89827e19d72aa1d', key.priv,
      'WIF decode produced wrong private key'
    )
    assert_equal(:mainnet, key.network, 'WIF should detect mainnet')
  end

  def test_imports_wif_mainnet_uncompressed
    key = Sibit::Key.new('5HueCGU8rMjxEXxiPuD5BDku4MkFqeZyd4dZ1jvhTVqvbTLvyTJ')
    assert_equal(
      '0c28fca386c7a227600b2fe50b7cae11ec86d3bf1fbe471be89827e19d72aa1d', key.priv,
      'uncompressed WIF decode produced wrong key'
    )
    assert_equal(:mainnet, key.network, 'uncompressed WIF should detect mainnet')
  end

  def test_imports_wif_testnet_compressed
    key = Sibit::Key.new('cMzLdeGd5vEqxB8B6VFQoRopQ3sLAAvEzDAoQgvX54xwofSWj1fx')
    assert_equal(
      '0c28fca386c7a227600b2fe50b7cae11ec86d3bf1fbe471be89827e19d72aa1d', key.priv,
      'testnet WIF decode produced wrong key'
    )
    assert_equal(:testnet, key.network, 'testnet WIF should detect testnet')
  end

  def test_imports_wif_testnet_uncompressed
    key = Sibit::Key.new('91gGn1HgSap6CbU12F6z3pJri26xzp7Ay1VW6NHCoEayNXwRpu2')
    assert_equal(
      '0c28fca386c7a227600b2fe50b7cae11ec86d3bf1fbe471be89827e19d72aa1d', key.priv,
      'testnet uncompressed WIF produced wrong key'
    )
    assert_equal(:testnet, key.network, 'testnet uncompressed WIF should detect testnet')
  end

  def test_wif_and_hex_produce_same_address
    assert_equal(
      Sibit::Key.new('0c28fca386c7a227600b2fe50b7cae11ec86d3bf1fbe471be89827e19d72aa1d').bech32,
      Sibit::Key.new('KwdMAjGmerYanjeui5SHS7JkmpZvVipYvB2LJGU1ZxJwYvP98617').bech32,
      'WIF and hex must produce same address'
    )
  end

  def test_accepts_uppercase_hex
    key = Sibit::Key.new('FD2333686F49D8647E1CE8D5EF39C304520B08F3C756B67068B30A3DB217DCB2')
    refute_nil(key.bech32, 'uppercase hex must be accepted')
    assert(key.bech32.start_with?('bc1q'), 'uppercase hex must produce valid address')
  end

  def test_uppercase_and_lowercase_produce_same_key
    assert_equal(
      Sibit::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2').bech32,
      Sibit::Key.new('FD2333686F49D8647E1CE8D5EF39C304520B08F3C756B67068B30A3DB217DCB2').bech32,
      'case must not affect address'
    )
  end

  def test_generated_key_survives_roundtrip
    original = Sibit::Key.generate
    restored = Sibit::Key.new(original.priv)
    assert_equal(original.priv, restored.priv, 'private key must survive roundtrip')
    assert_equal(original.pub, restored.pub, 'public key must survive roundtrip')
    assert_equal(original.bech32, restored.bech32, 'address must survive roundtrip')
  end

  def test_accepts_minimum_private_key
    refute_nil(
      Sibit::Key.new('0000000000000000000000000000000000000000000000000000000000000001').bech32,
      'minimum private key must be accepted'
    )
  end

  def test_accepts_maximum_private_key
    refute_nil(
      Sibit::Key.new('fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140').bech32,
      'maximum private key must be accepted'
    )
  end

  def test_rejects_curve_order
    order = 'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141'
    assert_raises(Sibit::Error) { Sibit::Key.new(order) }
  end

  def test_rejects_above_curve_order
    above = 'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364142'
    assert_raises(Sibit::Error) { Sibit::Key.new(above) }
  end

  def test_rejects_wif_with_invalid_checksum
    valid = 'KwdMAjGmerYanjeui5SHS7JkmpZvVipYvB2LJGU1ZxJwYvP98617'
    corrupted = valid[0..-2] + (valid[-1] == 'a' ? 'b' : 'a')
    assert_raises(Sibit::Error) { Sibit::Key.new(corrupted) }
  end

  def test_rejects_wif_with_invalid_version
    data = '990c28fca386c7a227600b2fe50b7cae11ec86d3bf1fbe471be89827e19d72aa1d01'
    invalid = Sibit::Base58.new(data + Digest::SHA256.hexdigest(Digest::SHA256.digest([data].pack('H*')))[0...8]).encode
    assert_raises(Sibit::Error) { Sibit::Key.new(invalid) }
  end

  def test_signs_empty_data
    key = Sibit::Key.generate
    assert(key.verify('', key.sign('')), 'empty data signature must verify')
  end

  def test_signs_large_data
    key = Sibit::Key.generate
    data = SecureRandom.random_bytes(1024)
    assert(key.verify(data, key.sign(data)), 'large data signature must verify')
  end

  def test_signature_is_der_encoded
    assert(
      Sibit::Key.generate.sign(SecureRandom.random_bytes(32)).start_with?("\x30"),
      'signature must be DER encoded sequence'
    )
  end

  def test_signatures_differ_for_same_data
    key = Sibit::Key.generate
    data = SecureRandom.random_bytes(32)
    refute_equal(key.sign(data), key.sign(data), 'ECDSA signatures must use random k')
  end

  def test_different_keys_produce_different_signatures
    data = SecureRandom.random_bytes(32)
    refute_equal(
      Sibit::Key.generate.sign(data), Sibit::Key.generate.sign(data),
      'different keys must produce different sigs'
    )
  end

  def test_signature_not_verifiable_by_different_key
    data = SecureRandom.random_bytes(32)
    refute(
      Sibit::Key.generate.verify(data, Sibit::Key.generate.sign(data)),
      'signature must not verify with wrong key'
    )
  end
end
