# frozen_string_literal: true

# Copyright (c) 2019-2025 Yegor Bugayenko
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
    assert(json[:txns].is_a?(Array))
    assert_equal('thash', json[:txns][0][:hash])
    assert(json[:txns][0][:outputs].is_a?(Array))
  end
end
