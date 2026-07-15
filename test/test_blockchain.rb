# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require 'json'
require 'webmock/minitest'
require_relative '../lib/sibit'
require_relative '../lib/sibit/blockchain'

# Sibit::Blockchain test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestBlockchain < Minitest::Test
  def test_fetch_block
    hash = '0000000000000000000f676241aabc9b62b748d26192a44bc25720c34de27d19'
    stub_request(:get, "https://blockchain.info/rawblock/#{hash}")
      .to_return(
        body: '{"next_block": ["n"], "prev_block": "p", "hash": "h",
        "tx": [{"hash": "h1", "out": [{"hash": "oh", "value": 123}]}]}'
      )
    json = Sibit::Blockchain.new.block(hash)
    assert(json[:next])
    assert(json[:previous])
    assert_equal('h', json[:hash])
    assert_kind_of(Array, json[:txns])
    assert_equal('h1', json[:txns][0][:hash])
    assert_kind_of(Array, json[:txns][0][:outputs])
  end

  def test_rejects_unknown_currency
    stub_request(:get, 'https://blockchain.info/ticker').to_return(body: '{}')
    assert_raises(Sibit::Error) { Sibit::Blockchain.new.price('XYZ') }
  end

  def test_next_of
    skip('does not work')
    hash = '0000000000000000000f676241aabc9b62b748d26192a44bc25720c34de27d19'
    stub_request(:get, "https://blockchain.info/rawblock/#{hash}")
      .to_return(body: '{"next_block": ["nxt"]}')
    assert_equal('nxt', Sibit::Blockchain.new.next_of(hash))
  end
end
