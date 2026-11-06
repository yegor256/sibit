# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require 'json'
require 'securerandom'
require 'webmock/minitest'
require_relative '../lib/sibit'
require_relative '../lib/sibit/sochain'

# Sibit::Sochain test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestSochain < Minitest::Test
  def test_fetches_price
    stub_request(:get, 'https://sochain.com/api/v3/price/BTC?currency=EUR')
      .to_return(body: { status: 'success', data: { value: '67301.89', currency: 'EUR' } }.to_json)
    assert_in_delta(67_301.89, Sibit::Sochain.new.price('EUR'), 0.001, 'price is wrong')
  end

  def test_fails_price_without_value
    stub_request(:get, 'https://sochain.com/api/v3/price/BTC?currency=USD')
      .to_return(body: { status: 'success', data: {} }.to_json)
    assert_raises(Sibit::Error, 'absent price cannot be silently accepted') do
      Sibit::Sochain.new.price('USD')
    end
  end

  def test_fetches_balance
    address = '1GkQmKAmHtNfnD3LHhTkewJxKHVSta4m2a'
    stub_request(:get, "https://sochain.com/api/v3/balance/BTC/#{address}")
      .to_return(
        body: { status: 'success', data: { confirmed: '0.00107868', unconfirmed: '0.1' } }.to_json
      )
    assert_equal(107_868, Sibit::Sochain.new.balance(address), 'confirmed balance is wrong')
  end

  def test_fails_balance_without_confirmed_field
    address = '1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2'
    stub_request(:get, "https://sochain.com/api/v3/balance/BTC/#{address}")
      .to_return(body: { status: 'success', data: { unconfirmed: '0' } }.to_json)
    assert_raises(Sibit::Error, 'absent balance cannot be reported as zero') do
      Sibit::Sochain.new.balance(address)
    end
  end

  def test_fails_balance_for_invalid_address
    stub_request(:get, 'https://sochain.com/api/v3/balance/BTC/bad')
      .to_return(
        status: 404, body: { status: 'fail', data: { error_message: 'Invalid address' } }.to_json
      )
    assert_raises(Sibit::Error, 'invalid address cannot be reported as zero') do
      Sibit::Sochain.new.balance('bad')
    end
  end

  def test_finds_latest_block
    hash = SecureRandom.hex(32)
    stub_request(:get, 'https://sochain.com/api/v3/best_block_hash/BTC')
      .to_return(body: { status: 'success', data: { hash: hash } }.to_json)
    assert_equal(hash, Sibit::Sochain.new.latest, 'latest block hash is wrong')
  end

  def test_finds_height
    hash = SecureRandom.hex(32)
    stub_request(:get, "https://sochain.com/api/v3/block/BTC/#{hash}")
      .to_return(body: { status: 'success', data: { hash: hash, height: 900_123 } }.to_json)
    assert_equal(900_123, Sibit::Sochain.new.height(hash), 'height is wrong')
  end

  def test_finds_next_block
    hash = SecureRandom.hex(32)
    nxt = SecureRandom.hex(32)
    stub_request(:get, "https://sochain.com/api/v3/block/BTC/#{hash}")
      .to_return(body: { status: 'success', data: { hash: hash, next_block_hash: nxt } }.to_json)
    assert_equal(nxt, Sibit::Sochain.new.next_of(hash), 'next block hash is wrong')
  end

  def test_returns_nil_when_block_is_the_tip
    hash = SecureRandom.hex(32)
    stub_request(:get, "https://sochain.com/api/v3/block/BTC/#{hash}")
      .to_return(body: { status: 'success', data: { hash: hash, next_block_hash: nil } }.to_json)
    assert_nil(Sibit::Sochain.new.next_of(hash), 'the tip of the chain cannot have a next block')
  end

  def test_fetches_utxos_from_all_pages
    address = '1GkQmKAmHtNfnD3LHhTkewJxKHVSta4m2a'
    stub_request(:get, 'https://sochain.com/api/v3/network_info/BTC')
      .to_return(body: { status: 'success', data: { block_count: 1_000 } }.to_json)
    full =
      Array.new(10) do
        { hash: SecureRandom.hex(32), index: 0, script: '00', value: '0.00000001', block: 1 }
      end
    stub_request(:get, "https://sochain.com/api/v3/unspent_outputs/BTC/#{address}/1")
      .to_return(body: { status: 'success', data: { outputs: full } }.to_json)
    last = { hash: 'cafe', index: 3, script: '76a914', value: '0.00027833', block: 991 }
    stub_request(:get, "https://sochain.com/api/v3/unspent_outputs/BTC/#{address}/2")
      .to_return(body: { status: 'success', data: { outputs: [last] } }.to_json)
    assert_equal(
      { value: 27_833, hash: 'cafe', index: 3, confirmations: 10, script: ['76a914'].pack('H*') },
      Sibit::Sochain.new.utxos([address])[10],
      'output from the second page is lost or wrong'
    )
  end

  def test_counts_no_confirmations_when_unconfirmed
    address = 'bc1qntndgqfx46wks63jep34cjk3pw63es86kp45c6'
    stub_request(:get, 'https://sochain.com/api/v3/network_info/BTC')
      .to_return(body: { status: 'success', data: { block_count: 777 } }.to_json)
    stub_request(:get, "https://sochain.com/api/v3/unspent_outputs/BTC/#{address}/1")
      .to_return(
        body: {
          status: 'success',
          data: {
            outputs: [{ hash: 'beef', index: 0, script: '0014', value: '0.0000001', block: nil }]
          }
        }.to_json
      )
    assert_equal(
      0, Sibit::Sochain.new.utxos([address])[0][:confirmations],
      'unconfirmed output has confirmations'
    )
  end

  def test_fails_utxos_without_outputs
    address = '1GkQmKAmHtNfnD3LHhTkewJxKHVSta4m2a'
    stub_request(:get, 'https://sochain.com/api/v3/network_info/BTC')
      .to_return(body: { status: 'success', data: { block_count: 5 } }.to_json)
    stub_request(:get, "https://sochain.com/api/v3/unspent_outputs/BTC/#{address}/1")
      .to_return(body: { status: 'success', data: {} }.to_json)
    assert_raises(Sibit::Error, 'missing outputs cannot pass as no unspent outputs') do
      Sibit::Sochain.new.utxos([address])
    end
  end

  def test_sends_api_key_in_header
    stub = stub_request(:get, 'https://sochain.com/api/v3/best_block_hash/BTC')
      .with(headers: { 'API-KEY' => 'k7Qz' })
      .to_return(body: { status: 'success', data: { hash: 'abc' } }.to_json)
    Sibit::Sochain.new(key: 'k7Qz').latest
    assert_requested(stub, times: 1, msg: 'API key is not sent in the header')
  end

  def test_uses_alternate_network
    stub_request(:get, 'https://sochain.com/api/v3/best_block_hash/LTC')
      .to_return(body: { status: 'success', data: { hash: '00ltc' } }.to_json)
    assert_equal('00ltc', Sibit::Sochain.new(network: 'LTC').latest, 'network is ignored')
  end

  def test_refuses_push
    assert_raises(Sibit::NotSupportedError, 'push cannot be pretended to work') do
      Sibit::Sochain.new.push('deadbeef')
    end
  end

  def test_refuses_block
    assert_raises(Sibit::NotSupportedError, 'block cannot be pretended to work') do
      Sibit::Sochain.new.block(SecureRandom.hex(32))
    end
  end

  def test_refuses_fees
    assert_raises(Sibit::NotSupportedError, 'fees cannot be pretended to work') { Sibit::Sochain.new.fees }
  end
end
