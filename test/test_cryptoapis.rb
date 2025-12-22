# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require 'webmock/minitest'
require 'json'
require_relative '../lib/sibit'
require_relative '../lib/sibit/cryptoapis'

# Sibit::Cryptoapis test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class TestCryptoapis < Minitest::Test
  def test_fetch_block
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    url = 'https://api.cryptoapis.io/v1/bc/btc/mainnet'
    stub_request(:get, "#{url}/blocks/#{hash}")
      .to_return(body: '{"payload": {"nextblockhash": "n", "hash": "h", "previousblockhash": "p"}}')
    stub_request(:get, "#{url}/txs/block/#{hash}?index=0&limit=200")
      .to_return(body: '{"payload": [{"hash": "thash",
        "txouts": [{"addresses": ["a1"], "value": 123}]}]}')
    sibit = Sibit::Cryptoapis.new('-')
    json = sibit.block(hash)
    assert(json[:next])
    assert(json[:previous])
    assert_equal('h', json[:hash])
    assert_kind_of(Array, json[:txns])
    assert_equal('thash', json[:txns][0][:hash])
    assert_kind_of(Array, json[:txns][0][:outputs])
  end

  def test_price_raises_not_supported
    sibit = Sibit::Cryptoapis.new('-')
    assert_raises(Sibit::NotSupportedError) { sibit.price('USD') }
  end

  def test_fees_raises_not_supported
    sibit = Sibit::Cryptoapis.new('-')
    assert_raises(Sibit::NotSupportedError) { sibit.fees }
  end

  def test_utxos_raises_not_supported
    sibit = Sibit::Cryptoapis.new('-')
    assert_raises(Sibit::NotSupportedError) { sibit.utxos(['addr']) }
  end

  def test_fetch_latest_block_hash
    stub_request(:get, 'https://api.cryptoapis.io/v1/bc/btc/mainnet/blocks/latest')
      .to_return(body: '{"payload": {"hash": "00000000abc123"}}')
    sibit = Sibit::Cryptoapis.new('-')
    hash = sibit.latest
    assert_equal('00000000abc123', hash, 'latest hash does not match')
  end

  def test_fetch_balance
    addr = '1Chain4asCYNnLVbvG6pgCLGBrtzh4Lx4b'
    stub_request(:get, "https://api.cryptoapis.io/v1/bc/btc/mainnet/address/#{addr}")
      .to_return(body: '{"payload": {"balance": "1.5"}}')
    sibit = Sibit::Cryptoapis.new('-')
    balance = sibit.balance(addr)
    assert_equal(150_000_000, balance, 'balance does not match')
  end

  def test_fetch_next_of_block
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    stub_request(:get, "https://api.cryptoapis.io/v1/bc/btc/mainnet/blocks/#{hash}")
      .to_return(body: '{"payload": {"hash": "00000000next"}}')
    sibit = Sibit::Cryptoapis.new('-')
    nxt = sibit.next_of(hash)
    assert_equal('00000000next', nxt, 'next block hash does not match')
  end

  def test_fetch_height
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    stub_request(:get, "https://api.cryptoapis.io/v1/bc/btc/mainnet/blocks/#{hash}")
      .to_return(body: '{"payload": {"height": 500000}}')
    sibit = Sibit::Cryptoapis.new('-')
    h = sibit.height(hash)
    assert_equal(500_000, h, 'block height does not match')
  end

  def test_push_transaction
    stub_request(:post, 'https://api.cryptoapis.io/v1/bc/btc/testnet/txs/send')
      .to_return(body: '{"payload": {"txid": "abc123"}}')
    sibit = Sibit::Cryptoapis.new('-')
    sibit.push('deadbeef')
  end

  def test_works_without_api_key
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    stub_request(:get, "https://api.cryptoapis.io/v1/bc/btc/mainnet/blocks/#{hash}")
      .to_return(body: '{"payload": {"height": 500000}}')
    sibit = Sibit::Cryptoapis.new('')
    h = sibit.height(hash)
    assert_equal(500_000, h, 'block height does not match')
  end
end
