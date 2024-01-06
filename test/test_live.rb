# frozen_string_literal: true

# Copyright (c) 2019-2024 Yegor Bugayenko
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
require 'backtrace'
require_relative '../lib/sibit'

# Live tests.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2024 Yegor Bugayenko
# License:: MIT
class TestLive < Minitest::Test
  def test_block
    for_each do |api|
      hash = '000000003031a0e73735690c5a1ff2a4be82553b2a12b776fbd3a215dc8f778d'
      json = api.block(hash)
      assert_equal(hash, json[:hash])
      assert(json[:txns].is_a?(Array))
      assert_equal(1, json[:txns].length)
      assert_equal(
        '20251a76e64e920e58291a30d4b212939aae976baca40e70818ceaa596fb9d37',
        json[:txns][0][:hash]
      )
      assert(json[:txns][0][:outputs].is_a?(Array))
      assert_equal(1, json[:txns][0][:outputs].length)
      out = json[:txns][0][:outputs][0]
      assert_equal('1GkQmKAmHtNfnD3LHhTkewJxKHVSta4m2a', out[:address])
      assert_equal(5_000_000_000, out[:value])
      assert(json[:next], 'Next block not found')
      assert(json[:previous], 'Previous block not found')
    end
  end

  def test_balance
    for_each do |api|
      hash = '1GkQmKAmHtNfnD3LHhTkewJxKHVSta4m2a'
      satoshi = api.balance(hash)
      assert(satoshi.is_a?(Integer), "Wrong type of balance: #{satoshi.class.name}")
      assert_equal(5_000_028_421, satoshi)
    end
  end

  def test_absent_balance
    for_each do |api|
      hash = '12NJ7DxjBMCkk7EFdb6nXnMsuJV1nAXGiM'
      satoshi = api.balance(hash)
      assert_equal(0, satoshi)
    end
  end

  def test_latest
    for_each do |api|
      hash = api.latest
      assert_equal(64, hash.length)
    end
  end

  def test_price
    for_each do |api|
      price = api.price
      assert(price.is_a?(Float))
    end
  end

  def test_next_of
    for_each do |api|
      hash = '000000003031a0e73735690c5a1ff2a4be82553b2a12b776fbd3a215dc8f778d'
      nxt = api.next_of(hash)
      assert_equal(
        '0000000071966c2b1d065fd446b1e485b2c9d9594acd2007ccbd5441cfc89444',
        nxt
      )
    end
  end

  def test_height
    for_each do |api|
      hash = '000000003031a0e73735690c5a1ff2a4be82553b2a12b776fbd3a215dc8f778d'
      height = api.height(hash)
      assert_equal(6, height)
    end
  end

  def test_utxos
    for_each do |api|
      json = api.utxos(['12fCwqBN4XsHq4iu2Wbfgq5e8YhqEGP3ee'])
      assert_equal(3, json.length)
      assert(json.find { |t| t[:value] == 16_200_000 }, 'UTXO not found')
      assert(json.find { |t| t[:script].unpack1('H*').start_with?('76a9141231e760') })
    end
  end

  private

  def for_each
    skip if ENV['skip_live']
    WebMock.allow_net_connect!
    apis = []
    require_relative '../lib/sibit/btc'
    apis << Sibit::Btc.new
    require_relative '../lib/sibit/blockchain'
    apis << Sibit::Blockchain.new
    require_relative '../lib/sibit/blockchair'
    apis << Sibit::Blockchair.new
    require_relative '../lib/sibit/cryptoapis'
    apis << Sibit::Cryptoapis.new('')
    require_relative '../lib/sibit/cex'
    apis << Sibit::Cex.new
    require_relative '../lib/sibit/bitcoinchain'
    apis << Sibit::Bitcoinchain.new
    apis.each do |api|
      yield api
    rescue Sibit::Error => e
      puts Backtrace.new(e)
    end
  end
end
