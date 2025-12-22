# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'webmock/minitest'
require 'json'
require_relative '../lib/sibit'
require_relative '../lib/sibit/cryptoapis'

# Sibit::Cryptoapis test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class TestCryptoapis < Minitest::Test
  def test_fetch_block
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    url = 'https://api.cryptoapis.io/v1/bc/btc/mainnet'
    stub_request(:get, "#{url}/blocks/#{hash}")
      .to_return(body: '{"payload": {"nextblockhash": "n", "hash": "h", "previousblockhash": "p"}}')
    stub_request(:get, "#{url}/txs/block/#{hash}?index=0&limit=200")
      .to_return(body: '{"payload": [{"hash": "thash",
        "txouts": [{"addresses": ["a1"], "value": 123}]}]}')
    sibit = Sibit::Cryptoapis.new('-')
    json = sibit.block(hash)
    assert(json[:next])
    assert(json[:previous])
    assert_equal('h', json[:hash])
    assert_kind_of(Array, json[:txns])
    assert_equal('thash', json[:txns][0][:hash])
    assert_kind_of(Array, json[:txns][0][:outputs])
  end
end
