# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require 'webmock/minitest'
require 'json'
require_relative '../lib/sibit'
require_relative '../lib/sibit/fake'

# Sibit::Fake test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class TestFake < Minitest::Test
  def test_fake_object_works
    sibit = Sibit::Fake.new
    assert_equal(4_000, sibit.price)
    assert_equal(12, sibit.fees[:S])
    assert_equal(100_000_000, sibit.balance(''))
    refute_empty(sibit.utxos(nil), 'utxos is empty')
    assert_equal('00000000000000000008df8a6e1b61d1136803ac9791b8725235c9f780b4ed71', sibit.latest)
  end

  def test_scan_works
    sibit = Sibit.new(api: Sibit::Fake.new)
    hash = '00000000000000000008df8a6e1b61d1136803ac9791b8725235c9f780b4ed71'
    found = false
    tail = sibit.scan(hash) do |addr, tx, satoshi|
      assert_equal(1000, satoshi)
      assert_equal('1HqhZx8U18TYS5paraTM1MzUQWb7ZbcG9u', addr)
      assert_equal("#{hash}:0", tx)
      found = true
    end
    assert(found)
    assert_equal(hash, tail)
  end
end
