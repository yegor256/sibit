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

  def test_never_rounds_small_regular_fee_to_zero
    stub_request(:get, 'https://api.blockchain.info/mempool/fees')
      .to_return(body: '{"regular":2,"priority":5,"limits":{"max":10}}')
    assert_equal(1, Sibit::Blockchain.new.fees[:S], 'small regular fee cannot round down to zero')
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

  def test_height
    hash = '0000000000000000000f676241aabc9b62b748d26192a44bc25720c34de27d19'
    stub_request(:get, "https://blockchain.info/rawblock/#{hash}")
      .to_return(body: '{"height": 600000}')
    assert_equal(600_000, Sibit::Blockchain.new.height(hash))
  end

  def test_height_raises_when_absent
    hash = '0000000000000000000f676241aabc9b62b748d26192a44bc25720c34de27d19'
    stub_request(:get, "https://blockchain.info/rawblock/#{hash}").to_return(body: '{}')
    assert_raises(Sibit::Error) do
      Sibit::Blockchain.new.height(hash)
    end
  end

  def test_reads_balance
    addr = '1Chain4asCYNnLVbvG6pgCLGBrtzh4Lx4b'
    stub_request(:get, "https://blockchain.info/rawaddr/#{addr}?limit=0")
      .to_return(body: '{"final_balance": 123, "n_tx": 1}')
    assert_equal(123, Sibit::Blockchain.new.balance(addr), 'balance does not match')
  end

  def test_balance_raises_on_server_error
    addr = '1Chain4asCYNnLVbvG6pgCLGBrtzh4Lx4b'
    stub_request(:get, "https://blockchain.info/rawaddr/#{addr}?limit=0")
      .to_return(status: 500, body: '{"error": "boom"}')
    assert_raises(Sibit::Error, 'a server error cannot be reported as a balance') do
      Sibit::Blockchain.new.balance(addr)
    end
  end

  def test_balance_raises_when_absent
    addr = '1Chain4asCYNnLVbvG6pgCLGBrtzh4Lx4b'
    stub_request(:get, "https://blockchain.info/rawaddr/#{addr}?limit=0")
      .to_return(body: '{"n_tx": 0}')
    assert_raises(Sibit::Error, 'a missing final_balance cannot pass as a balance') do
      Sibit::Blockchain.new.balance(addr)
    end
  end

  def test_push_wraps_body_in_tx_form
    stub = stub_request(:post, 'https://blockchain.info/pushtx')
      .with(body: 'tx=deadbeef', headers: { 'Content-Type' => 'application/x-www-form-urlencoded' })
      .to_return(body: '')
    Sibit::Blockchain.new.push('deadbeef')
    assert_requested(stub, times: 1)
  end
end
