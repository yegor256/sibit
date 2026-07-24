# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'backtrace'
require 'webmock/minitest'
require_relative '../lib/sibit'
require_relative '../lib/sibit/blockchain'
require_relative '../lib/sibit/key'
require_relative 'test__helper'

# Live payment test that signs and pushes a real mainnet transaction.
#
# This test only runs when the +REAL_PRIVATE_KEY+ environment variable is
# present and the derived address holds a positive, confirmed balance. It
# sweeps the entire balance back to the same address, which means every run
# only costs the miners fee. The transaction size and the minimum
# one-satoshi-per-byte fee are estimated exactly the way +Sibit#pay+ does,
# so the change output lands on zero and the whole balance is swept. Repeated
# runs re-spend the same UTXOs while the previous transaction is still in the
# mempool, so a mempool-conflict or "already known" response from the provider
# is treated as success.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestRealPay < Minitest::Test
  TOLERATED = Regexp.union(
    /already\s*(known|exists|in\s*(the\s*)?(block|mempool))/i,
    /txn-already-(known|in-mempool)/i,
    /txn-mempool-conflict/i,
    /missing\s*inputs/i,
    /bad-txns-inputs-missingorspent/i
  )

  def test_signs_and_pushes_real_self_send
    key = ENV.fetch('REAL_PRIVATE_KEY', nil)
    skip('REAL_PRIVATE_KEY is not set') if key.nil? || key.empty?
    WebMock.allow_net_connect!
    api = Sibit::Blockchain.new
    sibit = Sibit.new(api: api)
    addr = Sibit::Key.new(key).bech32
    utxos = api.utxos([addr]).select { |u| u[:confirmations]&.positive? }
    balance = utxos.sum { |u| u[:value] }
    skip("The balance of #{addr} is zero, nothing to send") if balance.zero?
    size = 100 + (utxos.count * 180)
    fee = size * Sibit::MIN_SATOSHI_PER_BYTE
    hash = sibit.pay(balance - fee, 1, [key], addr, addr)
    assert_match(/^[0-9a-f]{64}$/, hash, 'a real transaction hash must be returned')
  rescue Sibit::Error => e
    raise unless TOLERATED.match?(e.message)
    puts(Backtrace.new(e))
    skip("The transaction was rejected as a duplicate/conflict, which is fine: #{e.message}")
  end
end
