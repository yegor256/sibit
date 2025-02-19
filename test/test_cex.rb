# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'webmock/minitest'
require 'json'
require_relative '../lib/sibit'
require_relative '../lib/sibit/cex'

# Sibit::Cex test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class TestBtc < Minitest::Test
  def test_get_price
    stub_request(
      :get,
      'https://cex.io/api/last_price/BTC/USD'
    ).to_return(body: '{"lprice":123}')
    sibit = Sibit::Cex.new
    price = sibit.price
    assert_equal(123.0, price)
  end
end
