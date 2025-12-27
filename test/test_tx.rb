# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'test__helper'
require_relative '../lib/sibit/tx'
require_relative '../lib/sibit/key'

# Sibit::Tx test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class TestTx < Minitest::Test
  def test_creates_empty_transaction
    tx = Sibit::Tx.new
    assert_equal(0, tx.inputs.length, 'new tx should have no inputs')
  end

  def test_adds_output
    tx = Sibit::Tx.new
    tx.add_output(10_000, '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    assert_equal(1, tx.outputs.length, 'tx should have one output')
  end

  def test_output_has_correct_value
    tx = Sibit::Tx.new
    tx.add_output(50_000, '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    assert_equal(50_000, tx.outputs[0].value, 'output value does not match')
  end

  def test_output_generates_script
    tx = Sibit::Tx.new
    tx.add_output(10_000, '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    script = tx.outputs[0].script_hex
    assert(script.start_with?('76a914'), 'script does not start with OP_DUP OP_HASH160')
  end

  def test_adds_input
    tx = Sibit::Tx.new
    key = Sibit::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2')
    tx.add_input(
      hash: 'fc8fb1a526aef220b54a66bbb3e0549bf34db4f25e1aebc3feb87e86d341e65d',
      index: 0,
      script: '76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac',
      key: key
    )
    assert_equal(1, tx.inputs.length, 'tx should have one input')
  end

  def test_input_stores_previous_output_hash
    tx = Sibit::Tx.new
    key = Sibit::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2')
    hash = 'fc8fb1a526aef220b54a66bbb3e0549bf34db4f25e1aebc3feb87e86d341e65d'
    tx.add_input(hash: hash, index: 0,
                 script: '76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac', key: key)
    assert_equal(hash, tx.inputs[0].hash, 'input hash does not match')
  end

  def test_input_stores_previous_output_index
    tx = Sibit::Tx.new
    key = Sibit::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2')
    tx.add_input(
      hash: 'fc8fb1a526aef220b54a66bbb3e0549bf34db4f25e1aebc3feb87e86d341e65d',
      index: 2,
      script: '76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac',
      key: key
    )
    assert_equal(2, tx.inputs[0].prev_out_index, 'input index does not match')
  end

  def test_generates_transaction_hash
    tx = Sibit::Tx.new
    key = Sibit::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2')
    tx.add_input(
      hash: 'fc8fb1a526aef220b54a66bbb3e0549bf34db4f25e1aebc3feb87e86d341e65d',
      index: 0,
      script: '76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac',
      key: key
    )
    tx.add_output(10_000, '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    assert_match(/^[0-9a-f]{64}$/, tx.hash, 'tx hash format is invalid')
  end

  def test_generates_hex_payload
    tx = Sibit::Tx.new
    key = Sibit::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2')
    tx.add_input(
      hash: 'fc8fb1a526aef220b54a66bbb3e0549bf34db4f25e1aebc3feb87e86d341e65d',
      index: 0,
      script: '76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac',
      key: key
    )
    tx.add_output(10_000, '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    assert_match(/^[0-9a-f]+$/, tx.hex, 'tx hex format is invalid')
  end

  def test_in_returns_inputs
    tx = Sibit::Tx.new
    key = Sibit::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2')
    tx.add_input(
      hash: 'fc8fb1a526aef220b54a66bbb3e0549bf34db4f25e1aebc3feb87e86d341e65d',
      index: 0,
      script: '76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac',
      key: key
    )
    assert_equal(tx.inputs, tx.in, 'in method should return inputs')
  end

  def test_out_returns_outputs
    tx = Sibit::Tx.new
    tx.add_output(10_000, '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    assert_equal(tx.outputs, tx.out, 'out method should return outputs')
  end

  def test_supports_multiple_outputs
    tx = Sibit::Tx.new
    key = Sibit::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2')
    tx.add_input(
      hash: 'fc8fb1a526aef220b54a66bbb3e0549bf34db4f25e1aebc3feb87e86d341e65d',
      index: 0,
      script: '76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac',
      key: key
    )
    tx.add_output(10_000, '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    tx.add_output(20_000, '1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2')
    assert_equal(2, tx.outputs.length, 'tx should have two outputs')
  end

  def test_input_prev_out_returns_binary_hash
    tx = Sibit::Tx.new
    key = Sibit::Key.new('fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2')
    tx.add_input(
      hash: 'fc8fb1a526aef220b54a66bbb3e0549bf34db4f25e1aebc3feb87e86d341e65d',
      index: 0,
      script: '76a914c14b1e5c95a4687da3f7c932bf39a3a89bdb3fa988ac',
      key: key
    )
    assert_equal(32, tx.inputs[0].prev_out.length, 'prev_out should be 32 bytes')
  end

  def test_output_script_ends_with_checksig
    tx = Sibit::Tx.new
    tx.add_output(10_000, '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    script = tx.outputs[0].script_hex
    assert(script.end_with?('88ac'), 'script does not end with OP_EQUALVERIFY OP_CHECKSIG')
  end

  def test_output_generates_segwit_script
    tx = Sibit::Tx.new
    tx.add_output(10_000, 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4')
    script = tx.outputs[0].script_hex
    assert(script.start_with?('0014'), 'segwit script must start with OP_0 PUSH20')
  end

  def test_output_segwit_script_has_correct_length
    tx = Sibit::Tx.new
    tx.add_output(10_000, 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4')
    script = tx.outputs[0].script_hex
    assert_equal(44, script.length, 'P2WPKH script must be 22 bytes (44 hex chars)')
  end
end
