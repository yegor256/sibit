# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative '../lib/sibit/coins'
require_relative 'test__helper'

# Sibit::Coins test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestCoins < Minitest::Test
  def test_converts_two_decimal_btc_exactly
    assert_equal(29_000_000, Sibit::Coins.new('0.29').satoshi, 'must convert 0.29 BTC exactly')
  end

  def test_converts_small_fraction_btc_exactly
    assert_equal(7_000_000, Sibit::Coins.new('0.07').satoshi, 'must convert 0.07 BTC exactly')
  end

  def test_converts_float_amount_without_drift
    assert_equal(10_000_000, Sibit::Coins.new(0.1).satoshi, 'must convert a Float amount exactly')
  end

  def test_rejects_sub_satoshi_precision
    assert_raises(Sibit::Error, 'an amount finer than one satoshi cannot be accepted') do
      Sibit::Coins.new('0.000000001').satoshi
    end
  end

  def test_rejects_non_numeric_amount
    assert_raises(Sibit::Error, 'a non-numeric amount cannot be converted') do
      Sibit::Coins.new('this is not a number').satoshi
    end
  end
end
