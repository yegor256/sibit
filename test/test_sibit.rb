# frozen_string_literal: true

# Copyright (c) 2019 Yegor Bugayenko
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

# Sibit.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019 Yegor Bugayenko
# License:: MIT
class TestSibit < Minitest::Test
  def test_fetch_current_price
    stub_request(
      :get, 'https://blockchain.info/ticker'
    ).to_return(status: 200, body: '{"USD" : {"15m" : 5160.04}}')
    sibit = Sibit.new
    price = sibit.price
    assert(!price.nil?)
    assert_equal(5160.04, price, price)
  end

  def test_generate_key
    sibit = Sibit.new
    pkey = sibit.generate
    assert(!pkey.nil?)
    assert(/^[0-9a-f]{64}$/.match?(pkey))
  end

  def test_create_address
    sibit = Sibit.new
    pkey = sibit.generate
    puts "key: #{pkey}"
    address = sibit.create(pkey)
    puts "address: #{address}"
    assert(!address.nil?)
    assert(/^1[0-9a-zA-Z]+$/.match?(address))
  end

  def test_gets_balance
    stub_request(
      :get,
      'https://blockchain.info/rawaddr/1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f'
    ).to_return(status: 200, body: '{"final_balance": 100}')
    sibit = Sibit.new
    balance = sibit.balance('1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f')
    assert(balance.is_a?(Integer))
    assert_equal(100, balance)
  end

  def test_sends_payment
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
    ).to_return(status: 200, body: JSON.pretty_generate(json))
    stub_request(:post, 'https://blockchain.info/pushtx').to_return(status: 200)
    sibit = Sibit.new
    target = sibit.create(sibit.generate)
    change = sibit.create(sibit.generate)
    tx = sibit.pay(
      'fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2',
      '0.0001BTC', 'S',
      ['1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi'],
      target, change
    )
    assert(!tx.nil?)
    assert(tx.length > 30, tx)
  end
end
