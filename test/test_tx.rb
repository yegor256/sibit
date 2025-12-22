# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require_relative '../lib/sibit/bitcoin/tx'

# Sibit::Bitcoin::Tx test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class TestTx < Minitest::Test
  def test_creates_empty_transaction
    tx = Sibit::Bitcoin::Tx.new
    assert_equal(0, tx.inputs.length, 'new tx should have no inputs')
  end

  def test_adds_output
    tx = Sibit::Bitcoin::Tx.new
    tx.add_output(10_000, '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    assert_equal(1, tx.outputs.length, 'tx should have one output')
  end

  def test_output_has_correct_value
    tx = Sibit::Bitcoin::Tx.new
    tx.add_output(50_000, '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    assert_equal(50_000, tx.outputs[0].value, 'output value does not match')
  end

  def test_output_generates_script
    tx = Sibit::Bitcoin::Tx.new
    tx.add_output(10_000, '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi')
    script = tx.outputs[0].script_hex
    assert(script.start_with?('76a914'), 'script does not start with OP_DUP OP_HASH160')
  end
end
