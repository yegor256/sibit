# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require 'json'
require 'securerandom'
require 'webmock/minitest'
require_relative '../lib/sibit'
require_relative '../lib/sibit/cryptoapis'

# Sibit::Cryptoapis test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestCryptoapis < Minitest::Test
  def test_finds_next_block
    hash = SecureRandom.hex(32)
    nxt = SecureRandom.hex(32)
    stub_request(:get, "https://rest.cryptoapis.io/blockchain-data/bitcoin/mainnet/blocks/hash/#{hash}")
      .to_return(body: { data: { item: { hash: hash, nextBlockHash: nxt } } }.to_json)
    assert_equal(nxt, Sibit::Cryptoapis.new('k').next_of(hash), 'next block hash is wrong')
  end

  def test_returns_nil_when_block_is_the_tip
    hash = SecureRandom.hex(32)
    stub_request(:get, "https://rest.cryptoapis.io/blockchain-data/bitcoin/mainnet/blocks/hash/#{hash}")
      .to_return(body: { data: { item: { hash: hash, nextBlockHash: '' } } }.to_json)
    assert_nil(Sibit::Cryptoapis.new('k').next_of(hash), 'the tip cannot have a next block')
  end

  def test_fails_next_of_without_item
    hash = SecureRandom.hex(32)
    stub_request(:get, "https://rest.cryptoapis.io/blockchain-data/bitcoin/mainnet/blocks/hash/#{hash}")
      .to_return(body: { data: {} }.to_json)
    assert_raises(Sibit::Error, 'missing item cannot be silently accepted') do
      Sibit::Cryptoapis.new('k').next_of(hash)
    end
  end

  def test_finds_height
    hash = SecureRandom.hex(32)
    stub_request(:get, "https://rest.cryptoapis.io/blockchain-data/bitcoin/mainnet/blocks/hash/#{hash}")
      .to_return(body: { data: { item: { hash: hash, height: 812_377 } } }.to_json)
    assert_equal(812_377, Sibit::Cryptoapis.new('k').height(hash), 'height is wrong')
  end

  def test_finds_latest_block
    hash = SecureRandom.hex(32)
    stub_request(:get, 'https://rest.cryptoapis.io/blockchain-data/bitcoin/mainnet/blocks/last')
      .to_return(body: { data: { item: { hash: hash, height: 9 } } }.to_json)
    assert_equal(hash, Sibit::Cryptoapis.new('k').latest, 'latest block hash is wrong')
  end

  def test_fetches_balance_without_rounding_error
    address = '1Chain4asCYNnLVbvG6pgCLGBrtzh4Lx4b'
    stub_request(:get, "https://rest.cryptoapis.io/blockchain-data/bitcoin/mainnet/addresses/#{address}/balance")
      .to_return(
        body: { data: { item: { confirmedBalance: { amount: '0.29', unit: 'BTC' } } } }.to_json
      )
    assert_equal(29_000_000, Sibit::Cryptoapis.new('k').balance(address), 'balance is not exact')
  end

  def test_fails_balance_without_amount
    address = '1Chain4asCYNnLVbvG6pgCLGBrtzh4Lx4b'
    stub_request(:get, "https://rest.cryptoapis.io/blockchain-data/bitcoin/mainnet/addresses/#{address}/balance")
      .to_return(body: { data: { item: {} } }.to_json)
    assert_raises(Sibit::Error, 'absent balance cannot be reported as zero') do
      Sibit::Cryptoapis.new('k').balance(address)
    end
  end

  def test_sends_api_key_in_header
    stub = stub_request(:get, 'https://rest.cryptoapis.io/blockchain-data/bitcoin/mainnet/blocks/last')
      .with(headers: { 'X-API-Key' => 'q8Wz' })
      .to_return(body: { data: { item: { hash: 'abc' } } }.to_json)
    Sibit::Cryptoapis.new('q8Wz').latest
    assert_requested(stub, times: 1, msg: 'API key is not sent in the header')
  end

  def test_pushes_signed_hex
    hex = SecureRandom.hex(48)
    stub = stub_request(:post, 'https://rest.cryptoapis.io/blockchain-tools/bitcoin/mainnet/transactions/broadcast')
      .with(
        body: { data: { item: { signedTransactionHex: hex } } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      .to_return(body: { data: { item: { transactionId: 'abc' } } }.to_json)
    Sibit::Cryptoapis.new('k').push(hex)
    assert_requested(stub, times: 1, msg: 'signed transaction is not broadcast')
  end

  def test_fetches_block_with_all_pages
    hash = SecureRandom.hex(32)
    stub_request(:get, "https://rest.cryptoapis.io/blockchain-data/bitcoin/mainnet/blocks/hash/#{hash}")
      .to_return(
        body: { data: { item: { hash: hash, nextBlockHash: 'n', previousBlockHash: 'p' } } }.to_json
      )
    page =
      Array.new(50) do
        { transactionId: SecureRandom.hex(32), blockchainSpecific: { vout: [] } }
      end
    stub_request(
      :get,
      "https://rest.cryptoapis.io/blockchain-data/bitcoin/mainnet/blocks/hash/#{hash}/transactions?limit=50&offset=0"
    ).to_return(body: { data: { items: page } }.to_json)
    last = {
      transactionId: 'last',
      blockchainSpecific: { vout: [{ value: '0.29', scriptPubKey: { addresses: ['a1'] } }] }
    }
    stub_request(
      :get,
      "https://rest.cryptoapis.io/blockchain-data/bitcoin/mainnet/blocks/hash/#{hash}/transactions?limit=50&offset=50"
    ).to_return(body: { data: { items: [last] } }.to_json)
    assert_equal(
      { hash: 'last', outputs: [{ address: 'a1', value: 29_000_000 }] },
      Sibit::Cryptoapis.new('k').block(hash)[:txns][50],
      'transactions from the second page are lost or wrong'
    )
  end

  def test_reports_no_next_for_the_tip_block
    hash = SecureRandom.hex(32)
    stub_request(:get, "https://rest.cryptoapis.io/blockchain-data/bitcoin/mainnet/blocks/hash/#{hash}")
      .to_return(
        body: { data: { item: { hash: hash, nextBlockHash: '', previousBlockHash: 'p' } } }.to_json
      )
    stub_request(
      :get,
      "https://rest.cryptoapis.io/blockchain-data/bitcoin/mainnet/blocks/hash/#{hash}/transactions?limit=50&offset=0"
    ).to_return(body: { data: { items: [] } }.to_json)
    assert_nil(Sibit::Cryptoapis.new('k').block(hash)[:next], 'the tip cannot have a next block')
  end

  def test_refuses_price
    assert_raises(Sibit::NotSupportedError, 'price cannot be pretended to work') do
      Sibit::Cryptoapis.new('k').price('USD')
    end
  end

  def test_refuses_fees
    assert_raises(Sibit::NotSupportedError, 'fees cannot be pretended to work') { Sibit::Cryptoapis.new('k').fees }
  end

  def test_refuses_utxos
    assert_raises(Sibit::NotSupportedError, 'utxos cannot be pretended to work') do
      Sibit::Cryptoapis.new('k').utxos(['1Chain4asCYNnLVbvG6pgCLGBrtzh4Lx4b'])
    end
  end
end
