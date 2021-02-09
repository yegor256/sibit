# frozen_string_literal: true

# Copyright (c) 2019-2020 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'minitest/autorun'
require 'webmock/minitest'
require 'json'
require_relative '../lib/sibit'
require_relative '../lib/sibit/earn'
require_relative '../lib/sibit/fake'
require_relative '../lib/sibit/blockchain'
require_relative '../lib/sibit/firstof'
require_relative '../lib/sibit/bestof'

# Sibit.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2020 Yegor Bugayenko
# License:: MIT
class TestSibit < Minitest::Test
  def test_loads_fees
    stub_request(
      :get, 'https://bitcoinfees.earn.com/api/v1/fees/recommended'
    ).to_return(body: '{"fastestFee":300,"halfHourFee":200,"hourFee":180}')
    sibit = Sibit.new(api: Sibit::Earn.new)
    fees = sibit.fees
    assert_equal(60, fees[:S])
    assert_equal(180, fees[:M])
    assert_equal(200, fees[:L])
    assert_equal(300, fees[:XL])
  end

  def test_fetch_current_price
    stub_request(
      :get, 'https://blockchain.info/ticker'
    ).to_return(body: '{"USD" : {"15m" : 5160.04}}')
    sibit = Sibit.new
    price = sibit.price
    assert(!price.nil?)
    assert_equal(5160.04, price, price)
  end

  def test_generate_key
    sibit = Sibit.new(api: Sibit::Fake.new)
    pkey = sibit.generate
    assert(!pkey.nil?)
    assert(/^[0-9a-f]{64}$/.match?(pkey))
  end

  def test_generate_key_and_prints
    require 'stringio'
    require 'logger'
    strio = StringIO.new
    sibit = Sibit.new(log: Logger.new(strio), api: Sibit::Fake.new)
    key = sibit.generate
    assert(strio.string.include?('private key generated'))
    assert(strio.string.include?(key[0..4]))
    assert(!strio.string.include?(key))
  end

  def test_create_address
    sibit = Sibit.new(api: Sibit::Fake.new)
    pkey = sibit.generate
    puts "key: #{pkey}"
    address = sibit.create(pkey)
    puts "address: #{address}"
    assert(!address.nil?)
    assert(/^1[0-9a-zA-Z]+$/.match?(address))
    assert_equal(address, sibit.create(pkey))
  end

  def test_get_balance
    stub_request(
      :get,
      'https://blockchain.info/rawaddr/1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f?limit=0'
    ).to_return(body: '{"final_balance": 100}')
    sibit = Sibit.new
    balance = sibit.balance('1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f')
    assert(balance.is_a?(Integer))
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
      :get, 'https://bitcoinfees.earn.com/api/v1/fees/recommended'
    ).to_return(body: '{"fastestFee":300,"halfHourFee":200,"hourFee":180}')
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
    sibit = Sibit.new(api: Sibit::FirstOf.new([Sibit::Earn.new, Sibit::Blockchain.new]))
    target = sibit.create(sibit.generate)
    change = sibit.create(sibit.generate)
    tx = sibit.pay(
      '0.0001BTC', 'S',
      {
        '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi' =>
        'fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2'
      },
      target, change
    )
    assert(!tx.nil?)
    assert(tx.length > 30, tx)
  end

  def test_fail_if_not_enough_funds
    stub_request(
      :get, 'https://bitcoinfees.earn.com/api/v1/fees/recommended'
    ).to_return(body: '{"fastestFee":300,"halfHourFee":200,"hourFee":180}')
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
        {
          '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi' =>
          'fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2'
        },
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
    tail = sibit.scan('00000000000000000008df8a6e1b61d1136803ac9791b8725235c9f780b4ed71') do |addr, tx, satoshi|
      assert_equal(123, satoshi)
      assert_equal('addr', addr)
      assert_equal('hash:0', tx)
      found = true
    end
    assert(found)
    assert_equal('next', tail)
  end
end
