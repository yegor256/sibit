# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require_relative '../lib/sibit/bitcoin/txbuilder'

# Sibit::Bitcoin::TxBuilder test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class TestTxBuilder < Minitest::Test
  def test_builds_transaction_with_hash
    builder = Sibit::Bitcoin::TxBuilder.new
    key = Sibit::Bitcoin::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2')
    builder.input do |i|
      i.prev_out('fc8fb1a526aef220b54a66bbb3e0549bf34db4f25e1aebc3feb87e86d341e65d')
      i.prev_out_index(0)
      i.prev_out_script = '76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac'
      i.signature_key(key)
    end
    builder.output(10_000, '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    tx = builder.tx(input_value: 100_000, leave_fee: true, extra_fee: 1000,
                    change_address: '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    assert_match(/^[0-9a-f]{64}$/, tx.hash, 'tx hash format is wrong')
  end

  def test_serializes_to_hex
    builder = Sibit::Bitcoin::TxBuilder.new
    key = Sibit::Bitcoin::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2')
    builder.input do |i|
      i.prev_out('fc8fb1a526aef220b54a66bbb3e0549bf34db4f25e1aebc3feb87e86d341e65d')
      i.prev_out_index(0)
      i.prev_out_script = '76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac'
      i.signature_key(key)
    end
    builder.output(10_000, '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    tx = builder.tx(input_value: 100_000, leave_fee: true, extra_fee: 1000,
                    change_address: '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    hex = tx.to_payload.bth
    assert_match(/^[0-9a-f]+$/, hex, 'payload is not valid hex')
  end

  def test_creates_change_output
    builder = Sibit::Bitcoin::TxBuilder.new
    key = Sibit::Bitcoin::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2')
    builder.input do |i|
      i.prev_out('fc8fb1a526aef220b54a66bbb3e0549bf34db4f25e1aebc3feb87e86d341e65d')
      i.prev_out_index(0)
      i.prev_out_script = '76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac'
      i.signature_key(key)
    end
    builder.output(10_000, '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    tx = builder.tx(input_value: 100_000, leave_fee: true, extra_fee: 1000,
                    change_address: '1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2')
    assert_equal(2, tx.outputs.length, 'tx should have two outputs')
  end
end
