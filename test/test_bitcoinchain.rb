# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require 'webmock/minitest'
require 'json'
require_relative '../lib/sibit'
require_relative '../lib/sibit/bitcoinchain'

# Sibit::Bitcoinchain test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestBitcoinchain < Minitest::Test
  def test_fetch_hash
    stub_request(
      :get,
      'https://api-r.bitcoinchain.com/v1/status'
    ).to_return(body: '{"hash": "test"}')
    sibit = Sibit::Bitcoinchain.new
    hash = sibit.latest
    assert_equal('test', hash)
  end

  def test_fetch_balance
    hash = '1Chain4asCYNnLVbvG6pgCLGBrtzh4Lx4b'
    stub_request(:get, "https://api-r.bitcoinchain.com/v1/address/#{hash}")
      .to_return(body: '[{"balance": 5}]')
    sibit = Sibit::Bitcoinchain.new
    satoshi = sibit.balance(hash)
    assert_equal(500_000_000, satoshi)
  end

  def test_fetch_block
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    stub_request(:get, "https://api-r.bitcoinchain.com/v1/block/#{hash}")
      .to_return(
        body: '[{"next_block": "nn", "prev_block": "pp", "hash": "hh"}]'
      )
    stub_request(:get, "https://api-r.bitcoinchain.com/v1/block/txs/#{hash}")
      .to_return(
        body: '[{"txs":[{"self_hash":"hash123",
          "outputs":[{"value": 123, "receiver": "a1"}]}]}]'
      )
    sibit = Sibit::Bitcoinchain.new
    json = sibit.block(hash)
    assert_equal('nn', json[:next])
    assert_equal('pp', json[:previous])
    assert_equal('hh', json[:hash])
    assert_kind_of(Array, json[:txns])
    assert_equal('hash123', json[:txns][0][:hash])
    assert_kind_of(Array, json[:txns][0][:outputs])
  end
end
