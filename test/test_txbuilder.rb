# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require_relative '../lib/sibit/bitcoin/txbuilder'

# Sibit::TxBuilder test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class TestTxBuilder < Minitest::Test
  def test_builds_transaction_with_hash
    builder = Sibit::TxBuilder.new
    key = Sibit::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2')
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
    builder = Sibit::TxBuilder.new
    key = Sibit::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2')
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
    builder = Sibit::TxBuilder.new
    key = Sibit::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2')
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

  def test_skips_change_when_leave_fee_is_false
    builder = Sibit::TxBuilder.new
    key = Sibit::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2')
    builder.input do |i|
      i.prev_out('fc8fb1a526aef220b54a66bbb3e0549bf34db4f25e1aebc3feb87e86d341e65d')
      i.prev_out_index(0)
      i.prev_out_script = '76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac'
      i.signature_key(key)
    end
    builder.output(10_000, '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    tx = builder.tx(input_value: 100_000, leave_fee: false, extra_fee: 0,
                    change_address: '1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2')
    assert_equal(1, tx.outputs.length, 'tx should have only one output when leave_fee is false')
  end

  def test_skips_change_when_zero_or_negative
    builder = Sibit::TxBuilder.new
    key = Sibit::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2')
    builder.input do |i|
      i.prev_out('fc8fb1a526aef220b54a66bbb3e0549bf34db4f25e1aebc3feb87e86d341e65d')
      i.prev_out_index(0)
      i.prev_out_script = '76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac'
      i.signature_key(key)
    end
    builder.output(99_000, '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    tx = builder.tx(input_value: 100_000, leave_fee: true, extra_fee: 1000,
                    change_address: '1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2')
    assert_equal(1, tx.outputs.length, 'tx should skip zero change output')
  end

  def test_returns_inputs_via_in_method
    builder = Sibit::TxBuilder.new
    key = Sibit::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2')
    builder.input do |i|
      i.prev_out('fc8fb1a526aef220b54a66bbb3e0549bf34db4f25e1aebc3feb87e86d341e65d')
      i.prev_out_index(0)
      i.prev_out_script = '76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac'
      i.signature_key(key)
    end
    builder.output(10_000, '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    tx = builder.tx(input_value: 100_000, leave_fee: true, extra_fee: 1000,
                    change_address: '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    assert_equal(1, tx.in.length, 'in method should return inputs')
  end

  def test_returns_outputs_via_out_method
    builder = Sibit::TxBuilder.new
    key = Sibit::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2')
    builder.input do |i|
      i.prev_out('fc8fb1a526aef220b54a66bbb3e0549bf34db4f25e1aebc3feb87e86d341e65d')
      i.prev_out_index(0)
      i.prev_out_script = '76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac'
      i.signature_key(key)
    end
    builder.output(10_000, '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    tx = builder.tx(input_value: 100_000, leave_fee: true, extra_fee: 1000,
                    change_address: '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    assert_operator(tx.out.length, :>=, 1, 'out method should return outputs')
  end

  def test_supports_multiple_inputs
    builder = Sibit::TxBuilder.new
    key = Sibit::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2')
    builder.input do |i|
      i.prev_out('fc8fb1a526aef220b54a66bbb3e0549bf34db4f25e1aebc3feb87e86d341e65d')
      i.prev_out_index(0)
      i.prev_out_script = '76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac'
      i.signature_key(key)
    end
    builder.input do |i|
      i.prev_out('aa8fb1a526aef220b54a66bbb3e0549bf34db4f25e1aebc3feb87e86d341e65d')
      i.prev_out_index(1)
      i.prev_out_script = '76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac'
      i.signature_key(key)
    end
    builder.output(10_000, '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    tx = builder.tx(input_value: 200_000, leave_fee: true, extra_fee: 1000,
                    change_address: '1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2')
    assert_equal(2, tx.inputs.length, 'tx should have two inputs')
  end

  def test_supports_multiple_outputs
    builder = Sibit::TxBuilder.new
    key = Sibit::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2')
    builder.input do |i|
      i.prev_out('fc8fb1a526aef220b54a66bbb3e0549bf34db4f25e1aebc3feb87e86d341e65d')
      i.prev_out_index(0)
      i.prev_out_script = '76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac'
      i.signature_key(key)
    end
    builder.output(10_000, '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    builder.output(20_000, '1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2')
    tx = builder.tx(input_value: 100_000, leave_fee: true, extra_fee: 1000,
                    change_address: '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    assert_operator(tx.outputs.length, :>=, 2, 'tx should have at least two outputs')
  end

  def test_input_builder_stores_all_fields
    inp = Sibit::TxInputBuilder.new
    key = Sibit::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2')
    inp.prev_out('fc8fb1a526aef220b54a66bbb3e0549bf34db4f25e1aebc3feb87e86d341e65d')
    inp.prev_out_index(5)
    inp.prev_out_script = '76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac'
    inp.signature_key(key)
    assert_equal(
      'fc8fb1a526aef220b54a66bbb3e0549bf34db4f25e1aebc3feb87e86d341e65d',
      inp.prev_out_hash,
      'prev_out_hash does not match'
    )
    assert_equal(5, inp.prev_out_idx, 'prev_out_idx does not match')
    assert_equal('76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac', inp.script,
                 'script does not match')
    assert_equal(key, inp.key, 'key does not match')
  end
end
