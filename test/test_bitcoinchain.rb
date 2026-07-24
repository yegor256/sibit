# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require 'json'
require 'webmock/minitest'
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
    assert_equal('test', Sibit::Bitcoinchain.new.latest)
  end

  def test_fetch_balance
    hash = '1Chain4asCYNnLVbvG6pgCLGBrtzh4Lx4b'
    stub_request(:get, "https://api-r.bitcoinchain.com/v1/address/#{hash}")
      .to_return(body: '[{"balance": 5}]')
    assert_equal(500_000_000, Sibit::Bitcoinchain.new.balance(hash))
  end

  def test_fetch_balance_without_rounding_error
    hash = '1Chain4asCYNnLVbvG6pgCLGBrtzh4Lx4b'
    stub_request(:get, "https://api-r.bitcoinchain.com/v1/address/#{hash}")
      .to_return(body: '[{"balance": 0.29}]')
    assert_equal(29_000_000, Sibit::Bitcoinchain.new.balance(hash), 'balance must not truncate')
  end

  def test_reports_output_value_as_exact_satoshi
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    stub_request(:get, "https://api-r.bitcoinchain.com/v1/block/#{hash}")
      .to_return(body: '[{"next_block": "nn", "prev_block": "pp", "hash": "hh"}]')
    stub_request(:get, "https://api-r.bitcoinchain.com/v1/block/txs/#{hash}")
      .to_return(
        body: '[{"txs":[{"self_hash":"h","outputs":[{"value": 0.29, "receiver": "a"}]}]}]'
      )
    assert_equal(
      29_000_000,
      Sibit::Bitcoinchain.new.block(hash)[:txns][0][:outputs][0][:value],
      'output value must be exact satoshi'
    )
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
    json = Sibit::Bitcoinchain.new.block(hash)
    assert_equal('nn', json[:next])
    assert_equal('pp', json[:previous])
    assert_equal('hh', json[:hash])
    assert_kind_of(Array, json[:txns])
    assert_equal('hash123', json[:txns][0][:hash])
    assert_kind_of(Array, json[:txns][0][:outputs])
  end
end
