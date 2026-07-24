# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require 'json'
require 'webmock/minitest'
require_relative '../lib/sibit'
require_relative '../lib/sibit/blockchair'

# Sibit::Blockchair test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestBlockchair < Minitest::Test
  def test_fetch_balance
    hash = '1GkQmKAmHtNfnD3LHhTkewJxKHVSta4m2a'
    stub_request(:get, "https://api.blockchair.com/bitcoin/dashboards/address/#{hash}")
      .to_return(
        body: "{\"data\": {\"#{hash}\": {\"address\":
        {\"balance\": 1, \"transactions\": []}}}}"
      )
    assert_equal(1, Sibit::Blockchair.new.balance(hash))
  end

  def test_returns_zero_for_unknown_address
    hash = '1Unknown123Address'
    stub_request(:get, "https://api.blockchair.com/bitcoin/dashboards/address/#{hash}")
      .to_return(body: "{\"data\": {\"#{hash}\": null}}")
    assert_equal(
      0, Sibit::Blockchair.new.balance(hash),
      'unknown address should return zero balance'
    )
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
    Sibit::Blockchair.new.push('deadbeef')
  end

  def test_push_sends_body_verbatim
    stub = stub_request(:post, 'https://api.blockchair.com/bitcoin/push/transaction')
      .with(body: 'data=deadbeef')
      .to_return(body: '{"data": {"transaction_hash": "abc123"}}')
    Sibit::Blockchair.new.push('deadbeef')
    assert_requested(stub, times: 1)
  end

  def test_uses_api_key_in_requests
    hash = '1GkQmKAmHtNfnD3LHhTkewJxKHVSta4m2a'
    stub_request(:get, "https://api.blockchair.com/bitcoin/dashboards/address/#{hash}?key=testkey")
      .to_return(body: "{\"data\": {\"#{hash}\": {\"address\": {\"balance\": 100}}}}")
    assert_equal(
      100, Sibit::Blockchair.new(key: 'testkey').balance(hash),
      'balance with API key does not match'
    )
  end

  def test_push_with_api_key
    stub_request(:post, 'https://api.blockchair.com/bitcoin/push/transaction?key=testkey')
      .to_return(body: '{"data": {"transaction_hash": "abc123"}}')
    Sibit::Blockchair.new(key: 'testkey').push('deadbeef')
  end

  def test_balance_url_omits_key_when_nil
    hash = '1GkQmKAmHtNfnD3LHhTkewJxKHVSta4m2a'
    stub_request(:get, "https://api.blockchair.com/bitcoin/dashboards/address/#{hash}")
      .to_return(body: "{\"data\": {\"#{hash}\": {\"address\": {\"balance\": 1}}}}")
    assert_equal(1, Sibit::Blockchair.new.balance(hash))
  end

  def test_url_encodes_api_key
    hash = '1GkQmKAmHtNfnD3LHhTkewJxKHVSta4m2a'
    stub_request(:get, "https://api.blockchair.com/bitcoin/dashboards/address/#{hash}?key=key%26evil")
      .to_return(body: "{\"data\": {\"#{hash}\": {\"address\": {\"balance\": 5}}}}")
    assert_equal(5, Sibit::Blockchair.new(key: 'key&evil').balance(hash))
  end
end
