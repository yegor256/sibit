# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'json'
require 'webmock/minitest'
require_relative '../lib/sibit'
require_relative '../lib/sibit/bestof'
require_relative '../lib/sibit/blockchain'
require_relative '../lib/sibit/fake'
require_relative '../lib/sibit/firstof'
require_relative 'test__helper'

# Sibit.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class TestSibit < Minitest::Test
  def test_fetch_current_price
    stub_request(
      :get, 'https://blockchain.info/ticker'
    ).to_return(body: '{"USD" : {"15m" : 5160.04}}')
    sibit = Sibit.new
    price = sibit.price
    refute_nil(price)
    assert_in_delta(5160.04, price, 0.001, price)
  end

  def test_generate_key
    sibit = Sibit.new(api: Sibit::Fake.new)
    pkey = sibit.generate
    refute_nil(pkey)
    assert_match(/^[0-9a-f]{64}$/, pkey)
  end

  def test_generate_key_and_prints
    require 'stringio'
    require 'logger'
    strio = StringIO.new
    sibit = Sibit.new(log: Logger.new(strio), api: Sibit::Fake.new)
    key = sibit.generate
    assert_includes(strio.string, 'private key generated')
    assert_includes(strio.string, key[0..4])
    refute_includes(strio.string, key)
  end

  def test_create_address
    sibit = Sibit.new(api: Sibit::Fake.new)
    pkey = sibit.generate
    puts "key: #{pkey}"
    address = sibit.create(pkey)
    puts "address: #{address}"
    refute_nil(address)
    assert_match(/^1[0-9a-zA-Z]+$/, address)
    assert_equal(address, sibit.create(pkey))
  end

  def test_get_balance
    stub_request(
      :get,
      'https://blockchain.info/rawaddr/1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f?limit=0'
    ).to_return(body: '{"final_balance": 100}')
    sibit = Sibit.new
    balance = sibit.balance('1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f')
    assert_kind_of(Integer, balance)
    assert_equal(100, balance)
  end

  def test_get_latest_block
    stub_request(:get, 'https://blockchain.info/latestblock').to_return(
      body: '{"hash": "0000000000000538200a48202ca6340e983646ca088c7618ae82d68e0c76ef5a"}'
    )
    sibit = Sibit.new
    hash = sibit.latest
    assert_equal('0000000000000538200a48202ca6340e983646ca088c7618ae82d68e0c76ef5a', hash)
  end

  def test_send_payment
    stub_request(
      :get, 'https://api.blockchain.info/mempool/fees'
    ).to_return(body: '{"regular":300,"priority":200,"limits":{"max":88}}')
    stub_request(
      :get, 'https://blockchain.info/ticker'
    ).to_return(body: '{"USD" : {"15m" : 5160.04}}')
    json = {
      unspent_outputs: [
        {
          tx_hash: 'fc8fb1a526aef220b54a66bbb3e0549bf34db4f25e1aebc3feb87e86d341e65d',
          tx_hash_big_endian: '5de641d3867eb8fec3eb1a5ef2b44df39b54e0b3bb664ab520f2ae26a5b18ffc',
          tx_output_n: 0,
          script: '76a914c48a1737b35a9f9d9e3b624a910f1e22f7e80bbc88ac',
          value: 100_000
        }
      ]
    }
    stub_request(
      :get,
      'https://blockchain.info/unspent?active=1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi&limit=1000'
    ).to_return(body: JSON.pretty_generate(json))
    stub_request(:post, 'https://blockchain.info/pushtx').to_return(status: 200)
    sibit = Sibit.new(api: Sibit::FirstOf.new([Sibit::Blockchain.new]))
    target = sibit.create(sibit.generate)
    change = sibit.create(sibit.generate)
    tx = sibit.pay(
      '0.0001BTC', 'S+',
      ['fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2'],
      target, change
    )
    refute_nil(tx)
    assert_operator(tx.length, :>, 30, tx)
  end

  def test_fail_if_not_enough_funds
    stub_request(
      :get, 'https://blockchain.info/ticker'
    ).to_return(body: '{"USD" : {"15m" : 5160.04}}')
    json = {
      unspent_outputs: []
    }
    stub_request(
      :get,
      'https://blockchain.info/unspent?active=1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi&limit=1000'
    ).to_return(body: JSON.pretty_generate(json))
    sibit = Sibit.new(api: Sibit::BestOf.new([Sibit::Fake.new, Sibit::Fake.new]))
    target = sibit.create(sibit.generate)
    change = sibit.create(sibit.generate)
    assert_raises Sibit::Error do
      sibit.pay(
        '0.0001BTC', -5000,
        ['fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2'],
        target, change
      )
    end
  end

  def test_scan
    api = Object.new
    def api.block(hash)
      {
        hash: hash,
        orphan: false,
        next: 'next',
        previous: 'previous',
        txns: [
          {
            hash: 'hash',
            outputs: [
              {
                address: 'addr',
                value: 123
              }
            ]
          }
        ]
      }
    end
    sibit = Sibit.new(api: api)
    found = false
    start = '00000000000000000008df8a6e1b61d1136803ac9791b8725235c9f780b4ed71'
    tail = sibit.scan(start) do |addr, tx, satoshi|
      assert_equal(123, satoshi)
      assert_equal('addr', addr)
      assert_equal('hash:0', tx)
      found = true
    end
    assert(found)
    assert_equal('next', tail)
  end
end
