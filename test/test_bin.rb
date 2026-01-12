# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'json'
require 'webmock/minitest'
require_relative 'test__helper'
require_relative '../lib/sibit'
require_relative '../lib/sibit/bin'

# Tests for the CLI.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestBin < Minitest::Test
  def test_pay_with_max_amount_uses_balance
    stub_request(:get, 'https://blockchain.info/ticker')
      .to_return(body: '{"USD":{"15m":50000}}')
    stub_request(:get, 'https://api.blockchain.info/mempool/fees')
      .to_return(body: '{"regular":100,"priority":150,"limits":{"max":200}}')
    stub_request(:get, 'https://blockchain.info/rawaddr/bc1qcj9pwdant20em83mvf9fzrc7ytm7szau5ysh9x?limit=0')
      .to_return(body: '{"final_balance":50000}')
    json = {
      unspent_outputs: [
        {
          tx_hash: 'fc8fb1a526aef220b54a66bbb3e0549bf34db4f25e1aebc3feb87e86d341e65d',
          tx_hash_big_endian: '5de641d3867eb8fec3eb1a5ef2b44df39b54e0b3bb664ab520f2ae26a5b18ffc',
          tx_output_n: 0,
          script: '0014c48a1737b35a9f9d9e3b624a910f1e22f7e80bbc',
          confirmations: 6,
          value: 50_000
        }
      ]
    }
    stub_request(:get, 'https://blockchain.info/unspent?active=bc1qcj9pwdant20em83mvf9fzrc7ytm7szau5ysh9x&limit=1000')
      .to_return(body: JSON.pretty_generate(json))
    stub_request(:post, 'https://blockchain.info/pushtx')
      .to_return(status: 200)
    key = 'fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2'
    Sibit::Bin.start(
      [
        'pay', 'MAX', '100', key, 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4',
        'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4', '--yes', '--quiet'
      ]
    )
    assert_requested(
      :get,
      'https://blockchain.info/rawaddr/bc1qcj9pwdant20em83mvf9fzrc7ytm7szau5ysh9x?limit=0',
      times: 1
    )
  end
end
