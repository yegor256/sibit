# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'securerandom'
require_relative '../lib/sibit/bitcoin/key'

# Sibit::Bitcoin::Key test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class TestKey < Minitest::Test
  def test_generates_random_key
    key = Sibit::Bitcoin::Key.generate
    assert(/^[0-9a-f]{64}$/.match?(key.priv), 'private key format is wrong')
  end

  def test_creates_key_from_private
    pvt = 'fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2'
    key = Sibit::Bitcoin::Key.new(pvt)
    assert_equal(pvt, key.priv, 'private key does not match')
  end

  def test_derives_correct_address
    pvt = 'fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2'
    key = Sibit::Bitcoin::Key.new(pvt)
    assert_equal('1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi', key.addr, 'address does not match')
  end

  def test_signs_and_verifies
    key = Sibit::Bitcoin::Key.generate
    data = SecureRandom.random_bytes(32)
    sig = key.sign(data)
    assert(key.verify(data, sig), 'signature verification failed')
  end

  def test_returns_compressed_public_key
    key = Sibit::Bitcoin::Key.generate
    assert(/^0[23][0-9a-f]{64}$/.match?(key.pub), 'public key format is wrong')
  end
end
