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
require_relative '../lib/sibit/blockchain'

# Sibit::Blockchain test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2020 Yegor Bugayenko
# License:: MIT
class TestBlockchain < Minitest::Test
  def test_fetch_block
    hash = '0000000000000000000f676241aabc9b62b748d26192a44bc25720c34de27d19'
    stub_request(:get, "https://blockchain.info/rawblock/#{hash}")
      .to_return(body: '{"next_block": ["n"], "prev_block": "p", "hash": "h",
        "tx": [{"hash": "h1", "out": [{"hash": "oh", "value": 123}]}]}')
    sibit = Sibit::Blockchain.new
    json = sibit.block(hash)
    assert(json[:next])
    assert(json[:previous])
    assert_equal('h', json[:hash])
    assert(json[:txns].is_a?(Array))
    assert_equal('h1', json[:txns][0][:hash])
    assert(json[:txns][0][:outputs].is_a?(Array))
  end

  def test_next_of
    skip
    hash = '0000000000000000000f676241aabc9b62b748d26192a44bc25720c34de27d19'
    stub_request(:get, "https://blockchain.info/rawblock/#{hash}")
      .to_return(body: '{"next_block": ["nxt"]}')
    sibit = Sibit::Blockchain.new
    nxt = sibit.next_of(hash)
    assert_equal('nxt', nxt)
  end
end
