# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'webmock/minitest'
require 'json'
require_relative '../lib/sibit'
require_relative '../lib/sibit/blockchair'

# Sibit::Blockchair test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class TestBlockchair < Minitest::Test
  def test_fetch_balance
    hash = '1GkQmKAmHtNfnD3LHhTkewJxKHVSta4m2a'
    stub_request(:get, "https://api.blockchair.com/bitcoin/dashboards/address/#{hash}")
      .to_return(body: "{\"data\": {\"#{hash}\": {\"address\":
        {\"balance\": 1, \"transactions\": []}}}}")
    sibit = Sibit::Blockchair.new
    satoshi = sibit.balance(hash)
    assert_equal(1, satoshi)
  end
end
