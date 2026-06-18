# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require 'json'
require 'webmock/minitest'
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
    balance = Sibit::Btc.new.balance('1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f')
    assert_kind_of(Integer, balance)
    assert_equal(0, balance)
  end

  def test_get_zero_balance_no_txns
    stub_request(
      :get,
      'https://chain.api.btc.com/v3/address/1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f/unspent'
    ).to_return(body: '{"data":{}}')
    balance = Sibit::Btc.new.balance('1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f')
    assert_kind_of(Integer, balance)
    assert_equal(0, balance)
  end

  def test_get_broken_balance
    stub_request(
      :get,
      'https://chain.api.btc.com/v3/address/1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f/unspent'
    ).to_return(body: '{}')
    balance = Sibit::Btc.new.balance('1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f')
    assert_kind_of(Integer, balance)
    assert_equal(0, balance)
  end

  def test_get_empty_balance
    stub_request(
      :get,
      'https://chain.api.btc.com/v3/address/1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f/unspent'
    ).to_return(body: '{"data":null,"err_no":1,"err_msg":"Resource Not Found"}')
    balance = Sibit::Btc.new.balance('1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f')
    assert_kind_of(Integer, balance)
    assert_equal(0, balance)
  end

  def test_get_balance
    stub_request(
      :get,
      'https://chain.api.btc.com/v3/address/1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f/unspent'
    ).to_return(body: '{"data":{"list":[{"value":123}]}}')
    balance = Sibit::Btc.new.balance('1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f')
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
    assert_raises(Sibit::Error) do
      sibit.block(hash)
    end
  end

  def test_fetch_block
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(body: '{"data": {"next_block_hash": "n", "hash": "h", "prev_block_hash": "p"}}')
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}/tx?page=1&pagesize=50")
      .to_return(
        body: '{"data": {"list":[{"hash": "thash",
        "outputs": [{"addresses": ["a1"], "value": 123}]}]}}'
      )
    json = Sibit::Btc.new.block(hash)
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
    assert_equal('00000000abc123', Sibit::Btc.new.latest, 'latest hash does not match')
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
    assert_equal('00000000next', Sibit::Btc.new.next_of(hash), 'next block hash does not match')
  end

  def test_fetch_next_of_returns_nil_for_latest
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    zero = '0' * 64
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(body: %({"data": {"next_block_hash": "#{zero}"}}))
    assert_nil(Sibit::Btc.new.next_of(hash), 'next of latest block should be nil')
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
    assert_equal(500_000, Sibit::Btc.new.height(hash), 'block height does not match')
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
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}").to_return(body: '{"data": {}}')
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
    zero = '0' * 64
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(
        body: %({"data": {"next_block_hash": "#{zero}", "hash": "h", "prev_block_hash": "p"}})
      )
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}/tx?page=1&pagesize=50")
      .to_return(body: '{"data": {"list":[]}}')
    assert_nil(Sibit::Btc.new.block(hash)[:next], 'next should be nil for latest block')
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

  def test_utxos_accumulates_across_addresses
    alpha = '1AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    beta = '1BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB'
    stub_request(:get, "https://chain.api.btc.com/v3/address/#{alpha}/unspent")
      .to_return(body: '{"data":{"list":[{"tx_hash":"aaaa","confirmations":3}]}}')
    stub_request(:get, "https://chain.api.btc.com/v3/address/#{beta}/unspent")
      .to_return(body: '{"data":{"list":[{"tx_hash":"bbbb","confirmations":7}]}}')
    stub_request(:get, 'https://chain.api.btc.com/v3/tx/aaaa?verbose=3').to_return(
      body: %({"data":{"outputs":[{"addresses":["#{alpha}"],"value":100,"script_hex":"dead"}]}})
    )
    stub_request(:get, 'https://chain.api.btc.com/v3/tx/bbbb?verbose=3').to_return(
      body: %({"data":{"outputs":[{"addresses":["#{beta}"],"value":200,"script_hex":"cafe"}]}})
    )
    utxos = Sibit::Btc.new.utxos([alpha, beta])
    assert_equal(2, utxos.length)
    assert_equal(%w[aaaa bbbb], utxos.map { |u| u[:hash] })
    assert_equal([100, 200], utxos.map { |u| u[:value] })
    assert_equal([3, 7], utxos.map { |u| u[:confirmations] })
    utxos.each { |u| assert_kind_of(Integer, u[:index]) }
  end

  def test_utxos_skips_outputs_for_other_addresses
    mine = '1CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC'
    other = '1DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD'
    stub_request(:get, "https://chain.api.btc.com/v3/address/#{mine}/unspent")
      .to_return(body: '{"data":{"list":[{"tx_hash":"cccc","confirmations":1}]}}')
    stub_request(:get, 'https://chain.api.btc.com/v3/tx/cccc?verbose=3')
      .to_return(
        body: %({"data":{"outputs":[
          {"addresses":["#{other}"],"value":50,"script_hex":"00"},
          {"addresses":["#{mine}"],"value":75,"script_hex":"11"}
        ]}})
      )
    utxos = Sibit::Btc.new.utxos([mine])
    assert_equal(1, utxos.length)
    assert_equal(75, utxos[0][:value])
    assert_equal(1, utxos[0][:index])
  end

  def test_utxos_returns_empty_when_list_missing
    mine = '1EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE'
    stub_request(:get, "https://chain.api.btc.com/v3/address/#{mine}/unspent")
      .to_return(body: '{"data":{}}')
    assert_empty(Sibit::Btc.new.utxos([mine]))
  end

  def test_utxos_raises_when_data_missing
    mine = '1FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'
    stub_request(:get, "https://chain.api.btc.com/v3/address/#{mine}/unspent").to_return(body: '{}')
    assert_raises(Sibit::Error) { Sibit::Btc.new.utxos([mine]) }
  end
end
