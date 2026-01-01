# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require 'webmock/minitest'
require 'json'
require_relative '../lib/sibit'
require_relative '../lib/sibit/btc'

# Sibit::Btc test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestBtc < Minitest::Test
  def test_get_zero_balance
    stub_request(
      :get,
      'https://chain.api.btc.com/v3/address/1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f/unspent'
    ).to_return(body: '{"data":{"list":[]}}')
    sibit = Sibit::Btc.new
    balance = sibit.balance('1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f')
    assert_kind_of(Integer, balance)
    assert_equal(0, balance)
  end

  def test_get_zero_balance_no_txns
    stub_request(
      :get,
      'https://chain.api.btc.com/v3/address/1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f/unspent'
    ).to_return(body: '{"data":{}}')
    sibit = Sibit::Btc.new
    balance = sibit.balance('1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f')
    assert_kind_of(Integer, balance)
    assert_equal(0, balance)
  end

  def test_get_broken_balance
    stub_request(
      :get,
      'https://chain.api.btc.com/v3/address/1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f/unspent'
    ).to_return(body: '{}')
    sibit = Sibit::Btc.new
    balance = sibit.balance('1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f')
    assert_kind_of(Integer, balance)
    assert_equal(0, balance)
  end

  def test_get_empty_balance
    stub_request(
      :get,
      'https://chain.api.btc.com/v3/address/1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f/unspent'
    ).to_return(body: '{"data":null,"err_no":1,"err_msg":"Resource Not Found"}')
    sibit = Sibit::Btc.new
    balance = sibit.balance('1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f')
    assert_kind_of(Integer, balance)
    assert_equal(0, balance)
  end

  def test_get_balance
    stub_request(
      :get,
      'https://chain.api.btc.com/v3/address/1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f/unspent'
    ).to_return(body: '{"data":{"list":[{"value":123}]}}')
    sibit = Sibit::Btc.new
    balance = sibit.balance('1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f')
    assert_kind_of(Integer, balance)
    assert_equal(123, balance)
  end

  def test_fetch_block_broken
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(body: '{"data": {"next_block_hash": "n", "hash": "h", "prev_block_hash": "p"}}')
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}/tx?page=1&pagesize=50")
      .to_return(body: '{}')
    sibit = Sibit::Btc.new
    assert_raises Sibit::Error do
      sibit.block(hash)
    end
  end

  def test_fetch_block
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(body: '{"data": {"next_block_hash": "n", "hash": "h", "prev_block_hash": "p"}}')
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}/tx?page=1&pagesize=50")
      .to_return(body: '{"data": {"list":[{"hash": "thash",
        "outputs": [{"addresses": ["a1"], "value": 123}]}]}}')
    sibit = Sibit::Btc.new
    json = sibit.block(hash)
    assert(json[:next])
    assert(json[:previous])
    assert_equal('h', json[:hash])
    assert_kind_of(Array, json[:txns])
    assert_equal('thash', json[:txns][0][:hash])
    assert_kind_of(Array, json[:txns][0][:outputs])
  end

  def test_price_raises_not_supported
    sibit = Sibit::Btc.new
    assert_raises(Sibit::NotSupportedError) { sibit.price('USD') }
  end

  def test_fees_raises_not_supported
    sibit = Sibit::Btc.new
    assert_raises(Sibit::NotSupportedError) { sibit.fees }
  end

  def test_push_raises_not_supported
    sibit = Sibit::Btc.new
    assert_raises(Sibit::NotSupportedError) { sibit.push('abc123') }
  end

  def test_fetch_latest_block_hash
    stub_request(:get, 'https://chain.api.btc.com/v3/block/latest')
      .to_return(body: '{"data": {"hash": "00000000abc123"}}')
    sibit = Sibit::Btc.new
    hash = sibit.latest
    assert_equal('00000000abc123', hash, 'latest hash does not match')
  end

  def test_fetch_latest_raises_on_missing_data
    stub_request(:get, 'https://chain.api.btc.com/v3/block/latest')
      .to_return(body: '{"data": null}')
    sibit = Sibit::Btc.new
    assert_raises(Sibit::Error) { sibit.latest }
  end

  def test_fetch_next_of_block
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(body: '{"data": {"next_block_hash": "00000000next"}}')
    sibit = Sibit::Btc.new
    nxt = sibit.next_of(hash)
    assert_equal('00000000next', nxt, 'next block hash does not match')
  end

  def test_fetch_next_of_returns_nil_for_latest
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    zeros = '0000000000000000000000000000000000000000000000000000000000000000'
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(body: "{\"data\": {\"next_block_hash\": \"#{zeros}\"}}")
    sibit = Sibit::Btc.new
    nxt = sibit.next_of(hash)
    assert_nil(nxt, 'next of latest block should be nil')
  end

  def test_fetch_next_of_raises_on_missing_block
    hash = 'nonexistent'
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(body: '{"data": null}')
    sibit = Sibit::Btc.new
    assert_raises(Sibit::Error) { sibit.next_of(hash) }
  end

  def test_fetch_height
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(body: '{"data": {"height": 500000}}')
    sibit = Sibit::Btc.new
    h = sibit.height(hash)
    assert_equal(500_000, h, 'block height does not match')
  end

  def test_fetch_height_raises_on_missing_block
    hash = 'nonexistent'
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(body: '{"data": null}')
    sibit = Sibit::Btc.new
    assert_raises(Sibit::Error) { sibit.height(hash) }
  end

  def test_fetch_height_raises_on_missing_height
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(body: '{"data": {}}')
    sibit = Sibit::Btc.new
    assert_raises(Sibit::Error) { sibit.height(hash) }
  end

  def test_block_raises_on_missing_data
    hash = 'nonexistent'
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(body: '{"data": null}')
    sibit = Sibit::Btc.new
    assert_raises(Sibit::Error) { sibit.block(hash) }
  end

  def test_block_sets_next_to_nil_for_latest
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    zeros = '0000000000000000000000000000000000000000000000000000000000000000'
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(body: "{\"data\": {\"next_block_hash\": \"#{zeros}\", \
        \"hash\": \"h\", \"prev_block_hash\": \"p\"}}")
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}/tx?page=1&pagesize=50")
      .to_return(body: '{"data": {"list":[]}}')
    sibit = Sibit::Btc.new
    json = sibit.block(hash)
    assert_nil(json[:next], 'next should be nil for latest block')
  end

  def test_txns_raises_on_empty_list
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(body: '{"data": {"next_block_hash": "n", "hash": "h", "prev_block_hash": "p"}}')
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}/tx?page=1&pagesize=50")
      .to_return(body: '{"data": {"list": null}}')
    sibit = Sibit::Btc.new
    assert_raises(Sibit::Error) { sibit.block(hash) }
  end
end
