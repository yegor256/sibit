# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative '../lib/sibit/dry'
require_relative '../lib/sibit/fake'
require_relative 'test__helper'

# Sibit::Dry test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestDry < Minitest::Test
  def test_blocks_push
    assert_nil(Sibit::Dry.new(Sibit::Fake.new).push('deadbeef'), 'push must return nil in dry mode')
  end

  def test_delegates_price
    assert_equal(
      4_000, Sibit::Dry.new(Sibit::Fake.new).price,
      'price must be delegated to wrapped API'
    )
  end

  def test_delegates_balance
    assert_equal(
      100_000_000, Sibit::Dry.new(Sibit::Fake.new).balance('addr'),
      'balance must be delegated'
    )
  end

  def test_delegates_latest
    assert_match(
      /^[0-9a-f]{64}$/, Sibit::Dry.new(Sibit::Fake.new).latest,
      'latest must be delegated'
    )
  end

  def test_delegates_fees
    assert_equal(12, Sibit::Dry.new(Sibit::Fake.new).fees[:S], 'fees must be delegated')
  end

  def test_responds_to_delegated_methods
    api = Sibit::Dry.new(Sibit::Fake.new)
    assert_respond_to(api, :price, 'must respond to price')
    assert_respond_to(api, :balance, 'must respond to balance')
    assert_respond_to(api, :push, 'must respond to push')
  end
end
