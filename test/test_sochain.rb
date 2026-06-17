# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require 'json'
require 'webmock/minitest'
require_relative '../lib/sibit'
require_relative '../lib/sibit/sochain'

# Sibit::Sochain test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestSochain < Minitest::Test
  ADDR = '1GkQmKAmHtNfnD3LHhTkewJxKHVSta4m2a'
  BLOCK = '00000000000000000000abc'
  ZEROS = '0000000000000000000000000000000000000000000000000000000000000000'

  def test_fetch_price
    body = {
      status: 'success',
      data: { network: 'BTC', prices: [{ price: '42000.5', price_base: 'USD' }] }
    }
    stub_request(:get, 'https://sochain.com/api/v2/get_price/BTC/USD')
      .to_return(body: JSON.generate(body))
    assert_in_delta(42_000.5, Sibit::Sochain.new.price('USD'), 0.001)
  end

  def test_price_raises_when_no_data
    stub_request(:get, 'https://sochain.com/api/v2/get_price/BTC/EUR')
      .to_return(body: JSON.generate(status: 'fail', data: { prices: [] }))
    assert_raises(Sibit::Error) { Sibit::Sochain.new.price('EUR') }
  end

  def test_fetch_balance
    body = JSON.generate(
      status: 'success',
      data: { confirmed_balance: '0.00000123', unconfirmed_balance: '0' }
    )
    stub_request(:get, "https://sochain.com/api/v2/get_address_balance/BTC/#{ADDR}")
      .to_return(body: body)
    assert_equal(123, Sibit::Sochain.new.balance(ADDR))
  end

  def test_balance_zero_when_no_data
    stub_request(:get, 'https://sochain.com/api/v2/get_address_balance/BTC/1Unknown')
      .to_return(body: JSON.generate(status: 'fail', data: nil))
    assert_equal(0, Sibit::Sochain.new.balance('1Unknown'))
  end

  def test_balance_zero_when_no_confirmed_field
    stub_request(:get, 'https://sochain.com/api/v2/get_address_balance/BTC/1Empty')
      .to_return(body: JSON.generate(status: 'success', data: { unconfirmed_balance: '0' }))
    assert_equal(0, Sibit::Sochain.new.balance('1Empty'))
  end

  def test_latest_block
    body = JSON.generate(status: 'success', data: { blockhash: BLOCK, blocks: 800_000 })
    stub_request(:get, 'https://sochain.com/api/v2/get_info/BTC').to_return(body: body)
    assert_equal(BLOCK, Sibit::Sochain.new.latest)
  end

  def test_latest_raises_when_no_data
    stub_request(:get, 'https://sochain.com/api/v2/get_info/BTC')
      .to_return(body: JSON.generate(status: 'fail', data: nil))
    assert_raises(Sibit::Error) { Sibit::Sochain.new.latest }
  end

  def test_get_height
    body = JSON.generate(
      status: 'success',
      data: {
        blockhash: BLOCK,
        block_no: 750_000,
        next_blockhash: '00next',
        previous_blockhash: '00prev'
      }
    )
    stub_request(:get, "https://sochain.com/api/v2/block/BTC/#{BLOCK}").to_return(body: body)
    assert_equal(750_000, Sibit::Sochain.new.height(BLOCK))
  end

  def test_next_of_returns_hash
    body = JSON.generate(status: 'success', data: { blockhash: BLOCK, next_blockhash: '00next' })
    stub_request(:get, "https://sochain.com/api/v2/block/BTC/#{BLOCK}").to_return(body: body)
    assert_equal('00next', Sibit::Sochain.new.next_of(BLOCK))
  end

  def test_next_of_nil_for_zero_hash
    body = JSON.generate(status: 'success', data: { blockhash: BLOCK, next_blockhash: ZEROS })
    stub_request(:get, "https://sochain.com/api/v2/block/BTC/#{BLOCK}").to_return(body: body)
    assert_nil(Sibit::Sochain.new.next_of(BLOCK))
  end

  def test_fetch_utxos
    body = JSON.generate(
      status: 'success',
      data: {
        txs: [
          {
            txid: 'deadbeef',
            output_no: 0,
            value: '0.00010000',
            confirmations: 7,
            script_hex: '76a914bf47e52253df338ca4e8a70832247a504e24fe4588ac'
          }
        ]
      }
    )
    stub_request(
      :get,
      "https://sochain.com/api/v2/get_tx_unspent/BTC/#{ADDR}"
    ).to_return(body: body)
    utxos = Sibit::Sochain.new.utxos([ADDR])
    assert_equal(1, utxos.size)
    assert_equal(10_000, utxos.first[:value])
    assert_equal('deadbeef', utxos.first[:hash])
    assert_equal(0, utxos.first[:index])
    assert_equal(7, utxos.first[:confirmations])
  end

  def test_utxos_skips_addresses_without_data
    stub_request(:get, 'https://sochain.com/api/v2/get_tx_unspent/BTC/1NoData')
      .to_return(body: JSON.generate(status: 'fail', data: nil))
    assert_equal([], Sibit::Sochain.new.utxos(['1NoData']))
  end

  def test_fees_raises_not_supported
    assert_raises(Sibit::NotSupportedError) { Sibit::Sochain.new.fees }
  end

  def test_push_posts_hex_as_json
    stub_request(:post, 'https://sochain.com/api/v2/send_tx/BTC')
      .with(body: '{"tx_hex":"deadbeef"}', headers: { 'Content-Type' => 'application/json' })
      .to_return(body: JSON.generate(status: 'success', data: { txid: 'abc' }))
    Sibit::Sochain.new.push('deadbeef')
  end

  def test_push_raises_on_bad_status
    stub_request(:post, 'https://sochain.com/api/v2/send_tx/BTC')
      .to_return(status: 400, body: JSON.generate(status: 'fail'))
    assert_raises(Sibit::Error) { Sibit::Sochain.new.push('deadbeef') }
  end

  def test_uses_alternate_network
    stub_request(:get, 'https://sochain.com/api/v2/get_info/LTC')
      .to_return(body: JSON.generate(status: 'success', data: { blockhash: '00ltc', blocks: 1 }))
    assert_equal('00ltc', Sibit::Sochain.new(network: 'LTC').latest)
  end
end
