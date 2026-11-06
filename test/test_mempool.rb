# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require 'json'
require 'securerandom'
require 'webmock/minitest'
require_relative '../lib/sibit'
require_relative '../lib/sibit/mempool'

# Sibit::Mempool test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestMempool < Minitest::Test
  def test_finds_next_block
    hash = SecureRandom.hex(32)
    nxt = SecureRandom.hex(32)
    stub_request(:get, "https://mempool.space/api/block/#{hash}/status")
      .to_return(body: { in_best_chain: true, height: 42, next_best: nxt }.to_json)
    assert_equal(nxt, Sibit::Mempool.new.next_of(hash), 'next block hash is not returned')
  end

  def test_returns_nil_when_block_is_the_tip
    hash = SecureRandom.hex(32)
    stub_request(:get, "https://mempool.space/api/block/#{hash}/status")
      .to_return(body: { in_best_chain: true, height: 42, next_best: nil }.to_json)
    assert_nil(Sibit::Mempool.new.next_of(hash), 'the tip of the chain cannot have a next block')
  end

  def test_fails_next_of_for_unknown_block
    hash = SecureRandom.hex(32)
    stub_request(:get, "https://mempool.space/api/block/#{hash}/status")
      .to_return(status: 404, body: 'Block not found')
    assert_raises(Sibit::Error, 'unknown block cannot be silently accepted') do
      Sibit::Mempool.new.next_of(hash)
    end
  end

  def test_finds_height
    hash = SecureRandom.hex(32)
    stub_request(:get, "https://mempool.space/api/block/#{hash}")
      .to_return(body: { id: hash, height: 812_345 }.to_json)
    assert_equal(812_345, Sibit::Mempool.new.height(hash), 'height of the block is wrong')
  end

  def test_fails_when_height_is_absent
    hash = SecureRandom.hex(32)
    stub_request(:get, "https://mempool.space/api/block/#{hash}")
      .to_return(body: { id: hash }.to_json)
    assert_raises(Sibit::Error, 'absent height cannot be silently accepted') do
      Sibit::Mempool.new.height(hash)
    end
  end

  def test_finds_latest_block
    hash = SecureRandom.hex(32)
    stub_request(:get, 'https://mempool.space/api/blocks')
      .to_return(body: [{ id: hash, height: 9 }, { id: SecureRandom.hex(32), height: 8 }].to_json)
    assert_equal(hash, Sibit::Mempool.new.latest, 'latest block hash is wrong')
  end

  def test_fetches_balance
    address = '1GkQmKAmHtNfnD3LHhTkewJxKHVSta4m2a'
    stub_request(:get, "https://mempool.space/api/address/#{address}")
      .to_return(body: { chain_stats: { funded_txo_sum: 107_868, spent_txo_sum: 7_311 } }.to_json)
    assert_equal(100_557, Sibit::Mempool.new.balance(address), 'balance is not funded minus spent')
  end

  def test_fails_balance_on_malformed_response
    address = '1GkQmKAmHtNfnD3LHhTkewJxKHVSta4m2a'
    stub_request(:get, "https://mempool.space/api/address/#{address}").to_return(body: '{}')
    assert_raises(Sibit::Error, 'malformed response cannot be reported as zero balance') do
      Sibit::Mempool.new.balance(address)
    end
  end

  def test_fetches_fees
    stub_request(:get, 'https://mempool.space/api/v1/fees/recommended')
      .to_return(
        body: { fastestFee: 31, halfHourFee: 17, hourFee: 9, economyFee: 4, minimumFee: 1 }.to_json
      )
    assert_equal({ S: 4, M: 9, L: 17, XL: 31 }, Sibit::Mempool.new.fees, 'fees are mapped wrong')
  end

  def test_fetches_price
    stub_request(:get, 'https://mempool.space/api/v1/prices')
      .to_return(body: { time: 1, USD: 75_651, EUR: 67_708 }.to_json)
    assert_in_delta(67_708.0, Sibit::Mempool.new.price('EUR'), 0.01, 'price is wrong')
  end

  def test_fails_price_for_unknown_currency
    stub_request(:get, 'https://mempool.space/api/v1/prices')
      .to_return(body: { time: 1, USD: 75_651 }.to_json)
    assert_raises(Sibit::Error, 'unknown currency cannot be silently accepted') do
      Sibit::Mempool.new.price('XYZ')
    end
  end

  def test_fetches_utxos
    address = '1GkQmKAmHtNfnD3LHhTkewJxKHVSta4m2a'
    txid = SecureRandom.hex(32)
    stub_request(:get, 'https://mempool.space/api/blocks/tip/height').to_return(body: '1000')
    stub_request(:get, "https://mempool.space/api/address/#{address}/utxo")
      .to_return(
        body: [
          { txid: txid, vout: 1, value: 2_917, status: { confirmed: true, block_height: 991 } }
        ].to_json
      )
    stub_request(:get, "https://mempool.space/api/tx/#{txid}")
      .to_return(
        body: {
          vout: [{ scriptpubkey: 'aa', value: 5 }, { scriptpubkey: '76a914', value: 2_917 }]
        }.to_json
      )
    assert_equal(
      [{ value: 2_917, hash: txid, index: 1, confirmations: 10, script: ['76a914'].pack('H*') }],
      Sibit::Mempool.new.utxos([address]),
      'unspent outputs are wrong'
    )
  end

  def test_counts_no_confirmations_when_unconfirmed
    address = 'bc1qntndgqfx46wks63jep34cjk3pw63es86kp45c6'
    txid = SecureRandom.hex(32)
    stub_request(:get, 'https://mempool.space/api/blocks/tip/height').to_return(body: '777')
    stub_request(:get, "https://mempool.space/api/address/#{address}/utxo")
      .to_return(body: [{ txid: txid, vout: 0, value: 13, status: { confirmed: false } }].to_json)
    stub_request(:get, "https://mempool.space/api/tx/#{txid}")
      .to_return(body: { vout: [{ scriptpubkey: '0014', value: 13 }] }.to_json)
    assert_equal(
      0, Sibit::Mempool.new.utxos([address])[0][:confirmations],
      'unconfirmed output has confirmations'
    )
  end

  def test_pushes_raw_hex
    hex = SecureRandom.hex(64)
    stub = stub_request(:post, 'https://mempool.space/api/tx')
      .with(body: hex)
      .to_return(body: SecureRandom.hex(32))
    Sibit::Mempool.new.push(hex)
    assert_requested(stub, times: 1, msg: 'raw transaction is not posted verbatim')
  end

  def test_fetches_block_with_all_pages
    hash = SecureRandom.hex(32)
    stub_request(:get, "https://mempool.space/api/block/#{hash}")
      .to_return(body: { id: hash, tx_count: 26, previousblockhash: 'prev' }.to_json)
    stub_request(:get, "https://mempool.space/api/block/#{hash}/status")
      .to_return(body: { in_best_chain: true, next_best: 'next' }.to_json)
    page = Array.new(25) { { txid: SecureRandom.hex(32), vout: [] } }
    stub_request(:get, "https://mempool.space/api/block/#{hash}/txs/0")
      .to_return(body: page.to_json)
    stub_request(:get, "https://mempool.space/api/block/#{hash}/txs/25")
      .to_return(
        body: [{ txid: 'last', vout: [{ scriptpubkey_address: 'addr', value: 7 }] }].to_json
      )
    assert_equal(
      { hash: 'last', outputs: [{ address: 'addr', value: 7 }] },
      Sibit::Mempool.new.block(hash)[:txns][25],
      'transactions from the second page are lost'
    )
  end

  def test_marks_block_outside_best_chain_as_orphan
    hash = SecureRandom.hex(32)
    stub_request(:get, "https://mempool.space/api/block/#{hash}")
      .to_return(body: { id: hash, tx_count: 0, previousblockhash: 'prev' }.to_json)
    stub_request(:get, "https://mempool.space/api/block/#{hash}/status")
      .to_return(body: { in_best_chain: false, next_best: nil }.to_json)
    assert(Sibit::Mempool.new.block(hash)[:orphan], 'block outside the best chain is not an orphan')
  end
end
