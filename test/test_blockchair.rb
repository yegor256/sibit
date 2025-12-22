# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'webmock/minitest'
require 'json'
require_relative '../lib/sibit'
require_relative '../lib/sibit/blockchair'

# Sibit::Blockchair test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class TestBlockchair < Minitest::Test
  def test_fetch_balance
    hash = '1GkQmKAmHtNfnD3LHhTkewJxKHVSta4m2a'
    stub_request(:get, "https://api.blockchair.com/bitcoin/dashboards/address/#{hash}")
      .to_return(body: "{\"data\": {\"#{hash}\": {\"address\":
        {\"balance\": 1, \"transactions\": []}}}}")
    sibit = Sibit::Blockchair.new
    satoshi = sibit.balance(hash)
    assert_equal(1, satoshi)
  end

  def test_returns_zero_for_unknown_address
    hash = '1Unknown123Address'
    stub_request(:get, "https://api.blockchair.com/bitcoin/dashboards/address/#{hash}")
      .to_return(body: "{\"data\": {\"#{hash}\": null}}")
    sibit = Sibit::Blockchair.new
    satoshi = sibit.balance(hash)
    assert_equal(0, satoshi, 'unknown address should return zero balance')
  end

  def test_price_raises_not_supported
    sibit = Sibit::Blockchair.new
    assert_raises(Sibit::NotSupportedError) { sibit.price('USD') }
  end

  def test_height_raises_not_supported
    sibit = Sibit::Blockchair.new
    assert_raises(Sibit::NotSupportedError) { sibit.height('hash') }
  end

  def test_next_of_raises_not_supported
    sibit = Sibit::Blockchair.new
    assert_raises(Sibit::NotSupportedError) { sibit.next_of('hash') }
  end

  def test_fees_raises_not_supported
    sibit = Sibit::Blockchair.new
    assert_raises(Sibit::NotSupportedError) { sibit.fees }
  end

  def test_latest_raises_not_supported
    sibit = Sibit::Blockchair.new
    assert_raises(Sibit::NotSupportedError) { sibit.latest }
  end

  def test_utxos_raises_not_supported
    sibit = Sibit::Blockchair.new
    assert_raises(Sibit::NotSupportedError) { sibit.utxos(['addr']) }
  end

  def test_block_raises_not_supported
    sibit = Sibit::Blockchair.new
    assert_raises(Sibit::NotSupportedError) { sibit.block('hash') }
  end

  def test_push_transaction
    stub_request(:post, 'https://api.blockchair.com/bitcoin/push/transaction')
      .to_return(body: '{"data": {"transaction_hash": "abc123"}}')
    sibit = Sibit::Blockchair.new
    sibit.push('deadbeef')
  end

  def test_uses_api_key_in_requests
    hash = '1GkQmKAmHtNfnD3LHhTkewJxKHVSta4m2a'
    stub_request(:get, "https://api.blockchair.com/bitcoin/dashboards/address/#{hash}")
      .to_return(body: "{\"data\": {\"#{hash}\": {\"address\": {\"balance\": 100}}}}")
    sibit = Sibit::Blockchair.new(key: 'testkey')
    satoshi = sibit.balance(hash)
    assert_equal(100, satoshi, 'balance with API key does not match')
  end

  def test_push_with_api_key
    stub_request(:post, 'https://api.blockchair.com/bitcoin/push/transaction')
      .to_return(body: '{"data": {"transaction_hash": "abc123"}}')
    sibit = Sibit::Blockchair.new(key: 'testkey')
    sibit.push('deadbeef')
  end
end
