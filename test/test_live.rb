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

# Live tests.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2020 Yegor Bugayenko
# License:: MIT
class TestLive < Minitest::Test
  def test_fetch_block
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
      assert_equal(5_000_028_421, satoshi)
    end
  end

  def test_latest
    for_each do |api|
      hash = api.latest
      assert_equal(64, hash.length)
    end
  end

  private

  def for_each
    skip
    WebMock.allow_net_connect!
    apis = []
    require_relative '../lib/sibit/cryptoapis'
    apis << Sibit::Cryptoapis.new('--api-key--')
    require_relative '../lib/sibit/btc'
    apis << Sibit::Btc.new
    require_relative '../lib/sibit/bitcoinchain'
    apis << Sibit::Bitcoinchain.new
    require_relative '../lib/sibit/blockchain'
    apis << Sibit::Blockchain.new
    apis.each do |api|
      begin
        yield api
      rescue Sibit::Error => e
        puts e.message
      end
    end
  end
end