# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require 'json'
require 'webmock/minitest'
require_relative '../lib/sibit'
require_relative '../lib/sibit/btc'

# Sibit::Btc test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestBtc < Minitest::Test
  def test_get_zero_balance
    stub_request(
      :get,
      'https://chain.api.btc.com/v3/address/1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f/unspent'
    ).to_return(body: '{"data":{"list":[]}}')
    balance = Sibit::Btc.new.balance('1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f')
    assert_kind_of(Integer, balance)
    assert_equal(0, balance)
  end

  def test_get_zero_balance_no_txns
    stub_request(
      :get,
      'https://chain.api.btc.com/v3/address/1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f/unspent'
    ).to_return(body: '{"data":{}}')
    balance = Sibit::Btc.new.balance('1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f')
    assert_kind_of(Integer, balance)
    assert_equal(0, balance)
  end

  def test_balance_raises_on_api_error
    stub_request(
      :get,
      'https://chain.api.btc.com/v3/address/1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f/unspent'
    ).to_return(body: '{"data":null,"err_no":2,"err_msg":"System Error"}')
    assert_raises(Sibit::Error, 'an API error cannot be reported as zero balance') do
      Sibit::Btc.new.balance('1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f')
    end
  end

  def test_balance_raises_on_malformed_response
    stub_request(
      :get,
      'https://chain.api.btc.com/v3/address/1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f/unspent'
    ).to_return(body: '{}')
    assert_raises(Sibit::Error, 'a malformed response cannot be reported as zero balance') do
      Sibit::Btc.new.balance('1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f')
    end
  end

  def test_get_empty_balance
    stub_request(
      :get,
      'https://chain.api.btc.com/v3/address/1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f/unspent'
    ).to_return(body: '{"data":null,"err_no":1,"err_msg":"Resource Not Found"}')
    balance = Sibit::Btc.new.balance('1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f')
    assert_kind_of(Integer, balance)
    assert_equal(0, balance)
  end

  def test_get_balance
    stub_request(
      :get,
      'https://chain.api.btc.com/v3/address/1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f/unspent'
    ).to_return(body: '{"data":{"list":[{"value":123}]}}')
    balance = Sibit::Btc.new.balance('1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f')
    assert_kind_of(Integer, balance)
    assert_equal(123, balance)
  end

  def test_fetch_block_broken
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(body: '{"data": {"next_block_hash": "n", "hash": "h", "prev_block_hash": "p"}}')
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}/tx?page=1&pagesize=50")
      .to_return(body: '{}')
    sibit = Sibit::Btc.new
    assert_raises(Sibit::Error) do
      sibit.block(hash)
    end
  end

  def test_fetch_block
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(body: '{"data": {"next_block_hash": "n", "hash": "h", "prev_block_hash": "p"}}')
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}/tx?page=1&pagesize=50")
      .to_return(
        body: '{"data": {"list":[{"hash": "thash",
        "outputs": [{"addresses": ["a1"], "value": 123}]}]}}'
      )
    json = Sibit::Btc.new.block(hash)
    assert(json[:next])
    assert(json[:previous])
    assert_equal('h', json[:hash])
    assert_kind_of(Array, json[:txns])
    assert_equal('thash', json[:txns][0][:hash])
    assert_kind_of(Array, json[:txns][0][:outputs])
  end

  def test_price_raises_not_supported
    sibit = Sibit::Btc.new
    assert_raises(Sibit::NotSupportedError) { sibit.price('USD') }
  end

  def test_fees_raises_not_supported
    sibit = Sibit::Btc.new
    assert_raises(Sibit::NotSupportedError) { sibit.fees }
  end

  def test_push_raises_not_supported
    sibit = Sibit::Btc.new
    assert_raises(Sibit::NotSupportedError) { sibit.push('abc123') }
  end

  def test_fetch_latest_block_hash
    stub_request(:get, 'https://chain.api.btc.com/v3/block/latest')
      .to_return(body: '{"data": {"hash": "00000000abc123"}}')
    assert_equal('00000000abc123', Sibit::Btc.new.latest, 'latest hash does not match')
  end

  def test_fetch_latest_raises_on_missing_data
    stub_request(:get, 'https://chain.api.btc.com/v3/block/latest')
      .to_return(body: '{"data": null}')
    sibit = Sibit::Btc.new
    assert_raises(Sibit::Error) { sibit.latest }
  end

  def test_fetch_next_of_block
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(body: '{"data": {"next_block_hash": "00000000next"}}')
    assert_equal('00000000next', Sibit::Btc.new.next_of(hash), 'next block hash does not match')
  end

  def test_fetch_next_of_returns_nil_for_latest
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    zero = '0' * 64
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(body: %({"data": {"next_block_hash": "#{zero}"}}))
    assert_nil(Sibit::Btc.new.next_of(hash), 'next of latest block should be nil')
  end

  def test_fetch_next_of_raises_on_missing_block
    hash = 'nonexistent'
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(body: '{"data": null}')
    sibit = Sibit::Btc.new
    assert_raises(Sibit::Error) { sibit.next_of(hash) }
  end

  def test_fetch_height
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(body: '{"data": {"height": 500000}}')
    assert_equal(500_000, Sibit::Btc.new.height(hash), 'block height does not match')
  end

  def test_fetch_height_raises_on_missing_block
    hash = 'nonexistent'
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(body: '{"data": null}')
    sibit = Sibit::Btc.new
    assert_raises(Sibit::Error) { sibit.height(hash) }
  end

  def test_fetch_height_raises_on_missing_height
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}").to_return(body: '{"data": {}}')
    sibit = Sibit::Btc.new
    assert_raises(Sibit::Error) { sibit.height(hash) }
  end

  def test_block_raises_on_missing_data
    hash = 'nonexistent'
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(body: '{"data": null}')
    sibit = Sibit::Btc.new
    assert_raises(Sibit::Error) { sibit.block(hash) }
  end

  def test_block_sets_next_to_nil_for_latest
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    zero = '0' * 64
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(
        body: %({"data": {"next_block_hash": "#{zero}", "hash": "h", "prev_block_hash": "p"}})
      )
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}/tx?page=1&pagesize=50")
      .to_return(body: '{"data": {"list":[]}}')
    assert_nil(Sibit::Btc.new.block(hash)[:next], 'next should be nil for latest block')
  end

  def test_fetch_utxos_for_single_address
    addr = '1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f'
    stub_request(:get, "https://chain.api.btc.com/v3/address/#{addr}/unspent")
      .to_return(
        body: '{"data":{"list":[{"tx_hash":"aa","tx_output_n":0,"value":42,"confirmations":5}]}}'
      )
    stub_request(:get, 'https://chain.api.btc.com/v3/tx/aa?verbose=3')
      .to_return(
        body: %({"data":{"outputs":[{"addresses":["#{addr}"],"value":42,"script_hex":"00"}]}})
      )
    utxos = Sibit::Btc.new.utxos([addr])
    assert_kind_of(Array, utxos)
    assert_equal(1, utxos.length)
    out = utxos[0]
    assert_equal(42, out[:value])
    assert_equal('aa', out[:hash])
    assert_equal(0, out[:index])
    assert_equal(5, out[:confirmations])
    assert_kind_of(String, out[:script])
  end

  def test_fetch_utxos_accumulates_across_addresses
    one = '1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f'
    two = '1JSQBzkELK8UA9NVm4sZJ1CWGLEp8zUxR6'
    stub_request(:get, "https://chain.api.btc.com/v3/address/#{one}/unspent")
      .to_return(
        body: '{"data":{"list":[{"tx_hash":"aa","tx_output_n":0,"value":11,"confirmations":3}]}}'
      )
    stub_request(:get, "https://chain.api.btc.com/v3/address/#{two}/unspent")
      .to_return(
        body: '{"data":{"list":[{"tx_hash":"bb","tx_output_n":0,"value":22,"confirmations":4}]}}'
      )
    stub_request(:get, 'https://chain.api.btc.com/v3/tx/aa?verbose=3')
      .to_return(
        body: %({"data":{"outputs":[{"addresses":["#{one}"],"value":11,"script_hex":"00"}]}})
      )
    stub_request(:get, 'https://chain.api.btc.com/v3/tx/bb?verbose=3')
      .to_return(
        body: %({"data":{"outputs":[{"addresses":["#{two}"],"value":22,"script_hex":"01"}]}})
      )
    utxos = Sibit::Btc.new.utxos([one, two])
    assert_equal(2, utxos.length)
    assert_equal(%w[aa bb], utxos.map { |u| u[:hash] })
    assert_equal([11, 22], utxos.map { |u| u[:value] })
  end

  def test_fetch_utxos_skips_outputs_for_other_address
    addr = '1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f'
    other = '1OtherAddrCCCCCCCCCCCCCCCCCCCCCCCC'
    stub_request(:get, "https://chain.api.btc.com/v3/address/#{addr}/unspent")
      .to_return(
        body: '{"data":{"list":[{"tx_hash":"aa","tx_output_n":1,"value":7,"confirmations":1}]}}'
      )
    stub_request(:get, 'https://chain.api.btc.com/v3/tx/aa?verbose=3')
      .to_return(
        body: %({"data":{"outputs":[
          {"addresses":["#{other}"],"value":99,"script_hex":"FF"},
          {"addresses":["#{addr}"],"value":7,"script_hex":"00"}
        ]}})
      )
    utxos = Sibit::Btc.new.utxos([addr])
    assert_equal(1, utxos.length)
    assert_equal(7, utxos[0][:value])
    assert_equal(1, utxos[0][:index])
  end

  def test_fetch_utxos_raises_when_address_not_found
    addr = '1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f'
    stub_request(:get, "https://chain.api.btc.com/v3/address/#{addr}/unspent")
      .to_return(body: '{"data":null}')
    assert_raises(Sibit::Error) { Sibit::Btc.new.utxos([addr]) }
  end

  def test_fetch_utxos_returns_empty_when_list_is_nil
    addr = '1MZT1fa6y8H9UmbZV6HqKF4UY41o9MGT5f'
    stub_request(:get, "https://chain.api.btc.com/v3/address/#{addr}/unspent")
      .to_return(body: '{"data":{}}')
    utxos = Sibit::Btc.new.utxos([addr])
    assert_equal([], utxos)
  end

  def test_txns_raises_on_empty_list
    hash = '000000000000000007341915521967247f1dec17b3a311b8a8f4495392f1439b'
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}")
      .to_return(body: '{"data": {"next_block_hash": "n", "hash": "h", "prev_block_hash": "p"}}')
    stub_request(:get, "https://chain.api.btc.com/v3/block/#{hash}/tx?page=1&pagesize=50")
      .to_return(body: '{"data": {"list": null}}')
    sibit = Sibit::Btc.new
    assert_raises(Sibit::Error) { sibit.block(hash) }
  end

  def test_utxos_accumulates_across_addresses
    alpha = '1AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    beta = '1BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB'
    stub_request(:get, "https://chain.api.btc.com/v3/address/#{alpha}/unspent")
      .to_return(
        body: '{"data":{"list":[{"tx_hash":"aaaa","tx_output_n":0,"value":100,"confirmations":3}]}}'
      )
    stub_request(:get, "https://chain.api.btc.com/v3/address/#{beta}/unspent")
      .to_return(
        body: '{"data":{"list":[{"tx_hash":"bbbb","tx_output_n":0,"value":200,"confirmations":7}]}}'
      )
    stub_request(:get, 'https://chain.api.btc.com/v3/tx/aaaa?verbose=3').to_return(
      body: %({"data":{"outputs":[{"addresses":["#{alpha}"],"value":100,"script_hex":"dead"}]}})
    )
    stub_request(:get, 'https://chain.api.btc.com/v3/tx/bbbb?verbose=3').to_return(
      body: %({"data":{"outputs":[{"addresses":["#{beta}"],"value":200,"script_hex":"cafe"}]}})
    )
    utxos = Sibit::Btc.new.utxos([alpha, beta])
    assert_equal(2, utxos.length)
    assert_equal(%w[aaaa bbbb], utxos.map { |u| u[:hash] })
    assert_equal([100, 200], utxos.map { |u| u[:value] })
    assert_equal([3, 7], utxos.map { |u| u[:confirmations] })
    utxos.each { |u| assert_kind_of(Integer, u[:index]) }
  end

  def test_utxos_skips_outputs_for_other_addresses
    mine = '1CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC'
    other = '1DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD'
    stub_request(:get, "https://chain.api.btc.com/v3/address/#{mine}/unspent")
      .to_return(
        body: '{"data":{"list":[{"tx_hash":"cccc","tx_output_n":1,"value":75,"confirmations":1}]}}'
      )
    stub_request(:get, 'https://chain.api.btc.com/v3/tx/cccc?verbose=3')
      .to_return(
        body: %({"data":{"outputs":[
          {"addresses":["#{other}"],"value":50,"script_hex":"00"},
          {"addresses":["#{mine}"],"value":75,"script_hex":"11"}
        ]}})
      )
    utxos = Sibit::Btc.new.utxos([mine])
    assert_equal(1, utxos.length)
    assert_equal(75, utxos[0][:value])
    assert_equal(1, utxos[0][:index])
  end

  def test_utxos_returns_empty_when_list_missing
    mine = '1EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE'
    stub_request(:get, "https://chain.api.btc.com/v3/address/#{mine}/unspent")
      .to_return(body: '{"data":{}}')
    assert_empty(Sibit::Btc.new.utxos([mine]))
  end

  def test_utxos_raises_when_data_missing
    mine = '1FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'
    stub_request(:get, "https://chain.api.btc.com/v3/address/#{mine}/unspent").to_return(body: '{}')
    assert_raises(Sibit::Error) { Sibit::Btc.new.utxos([mine]) }
  end

  def test_utxos_emits_only_the_unspent_output
    addr = '1FundedTwiceAAAAAAAAAAAAAAAAAAAAAA'
    stub_request(:get, "https://chain.api.btc.com/v3/address/#{addr}/unspent")
      .to_return(
        body: '{"data":{"list":[{"tx_hash":"ff","tx_output_n":3,"value":1000,"confirmations":6}]}}'
      )
    stub_request(:get, 'https://chain.api.btc.com/v3/tx/ff?verbose=3')
      .to_return(
        body: %({"data":{"outputs":[
          {"addresses":["#{addr}"],"value":500,"script_hex":"aa"},
          {"addresses":["1Other"],"value":10,"script_hex":"bb"},
          {"addresses":["1Other"],"value":10,"script_hex":"cc"},
          {"addresses":["#{addr}"],"value":1000,"script_hex":"dd"}
        ]}})
      )
    assert_equal(
      1, Sibit::Btc.new.utxos([addr]).length,
      'a spent sibling output cannot be emitted as spendable'
    )
  end

  def test_utxos_takes_index_from_tx_output_n
    addr = '1FundedTwiceBBBBBBBBBBBBBBBBBBBBBB'
    stub_request(:get, "https://chain.api.btc.com/v3/address/#{addr}/unspent")
      .to_return(
        body: '{"data":{"list":[{"tx_hash":"ff","tx_output_n":3,"value":1000,"confirmations":6}]}}'
      )
    stub_request(:get, 'https://chain.api.btc.com/v3/tx/ff?verbose=3')
      .to_return(
        body: %({"data":{"outputs":[
          {"addresses":["#{addr}"],"value":500,"script_hex":"aa"},
          {"addresses":["1Other"],"value":10,"script_hex":"bb"},
          {"addresses":["1Other"],"value":10,"script_hex":"cc"},
          {"addresses":["#{addr}"],"value":1000,"script_hex":"dd"}
        ]}})
      )
    assert_equal(3, Sibit::Btc.new.utxos([addr])[0][:index], 'the index must come from tx_output_n')
  end

  def test_utxos_never_duplicates_multi_output_funding
    addr = '1FundedTwiceCCCCCCCCCCCCCCCCCCCCCC'
    stub_request(:get, "https://chain.api.btc.com/v3/address/#{addr}/unspent")
      .to_return(
        body: %({"data":{"list":[
          {"tx_hash":"ee","tx_output_n":0,"value":100,"confirmations":2},
          {"tx_hash":"ee","tx_output_n":1,"value":200,"confirmations":2}
        ]}})
      )
    stub_request(:get, 'https://chain.api.btc.com/v3/tx/ee?verbose=3')
      .to_return(
        body: %({"data":{"outputs":[
          {"addresses":["#{addr}"],"value":100,"script_hex":"aa"},
          {"addresses":["#{addr}"],"value":200,"script_hex":"bb"}
        ]}})
      )
    assert_equal(
      [0, 1], Sibit::Btc.new.utxos([addr]).map { |u| u[:index] },
      'each unspent outpoint cannot appear more than once'
    )
  end

  def test_utxos_raises_when_tx_output_n_missing
    addr = '1NoIndexDDDDDDDDDDDDDDDDDDDDDDDDDDD'
    stub_request(:get, "https://chain.api.btc.com/v3/address/#{addr}/unspent")
      .to_return(body: '{"data":{"list":[{"tx_hash":"aa","value":5,"confirmations":1}]}}')
    assert_raises(Sibit::Error, 'a missing tx_output_n cannot be guessed') do
      Sibit::Btc.new.utxos([addr])
    end
  end
end
