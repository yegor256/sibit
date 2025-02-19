# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'webmock/minitest'
require 'json'
require_relative '../lib/sibit'
require_relative '../lib/sibit/blockchain'

# Sibit::Blockchain test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
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
