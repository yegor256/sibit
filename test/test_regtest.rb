# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'json'
require 'loog'
require 'net/http'
require 'uri'
require 'webmock/minitest'
require_relative '../lib/sibit'
require_relative 'test__helper'

# Regtest integration tests using Docker.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class TestRegtest < Minitest::Test
  def test_sends_payment_in_regtest
    in_docker do |ctx|
      addr = ctx.address
      ctx.mine(101, addr)
      target = ctx.address
      tx = ctx.sibit.pay(
        10_000, 1000, [ctx.rpc('dumpprivkey', [addr])], target, addr,
        network: :regtest
      )
      assert_equal(
        10_000, ctx.outputs(tx, ctx.mine(1, addr).first)[target],
        'target must receive exactly 10000 satoshis'
      )
    end
  end

  def test_sibit_generated_keys_send_payment
    in_docker do |ctx|
      key = Sibit::Key.generate(network: :regtest)
      addr = key.bech32
      miner = ctx.address
      ctx.mine(101, miner)
      ctx.import(addr)
      ctx.fund(addr, 0.001)
      ctx.mine(1, miner)
      target = ctx.address
      tx = ctx.sibit.pay(50_000, 1000, [key.priv], target, addr, network: :regtest)
      assert_equal(
        50_000, ctx.outputs(tx, ctx.mine(1, miner).first)[target],
        'target must receive payment from a sibit-generated key'
      )
    end
  end

  def test_multihop_payment_chain
    in_docker do |ctx|
      keypairs = Array.new(3) { Sibit::Key.generate(network: :regtest) }
      keys = keypairs.map(&:priv)
      addrs = keypairs.map(&:bech32)
      addrs.each { |a| ctx.import(a) }
      miner = ctx.address
      ctx.mine(101, miner)
      ctx.fund(addrs[0], 0.01)
      ctx.mine(1, miner)
      ctx.sibit.pay(500_000, 1000, [keys[0]], addrs[1], addrs[0], network: :regtest)
      ctx.mine(1, miner)
      ctx.sibit.pay(400_000, 1000, [keys[1]], addrs[2], addrs[1], network: :regtest)
      ctx.mine(1, miner)
      assert_equal(
        400_000, ctx.api.utxos([addrs[2]]).sum { |u| u[:value] },
        'the last address in the chain must hold the full amount'
      )
    end
  end

  def test_roundtrip_payment
    in_docker do |ctx|
      akey = Sibit::Key.generate(network: :regtest)
      bkey = Sibit::Key.generate(network: :regtest)
      aaddr = akey.bech32
      baddr = bkey.bech32
      ctx.import(aaddr)
      ctx.import(baddr)
      miner = ctx.address
      ctx.mine(101, miner)
      ctx.fund(aaddr, 0.01)
      ctx.mine(1, miner)
      ctx.sibit.pay(500_000, 1000, [akey.priv], baddr, aaddr, network: :regtest)
      ctx.mine(1, miner)
      tx = ctx.sibit.pay(400_000, 1000, [bkey.priv], aaddr, baddr, network: :regtest)
      assert_equal(
        400_000, ctx.outputs(tx, ctx.mine(1, miner).first)[aaddr],
        'alice must receive 400000 satoshis back from bob'
      )
    end
  end

  def test_multiple_inputs_from_same_address
    in_docker do |ctx|
      skey = Sibit::Key.generate(network: :regtest)
      addr = skey.bech32
      taddr = Sibit::Key.generate(network: :regtest).bech32
      ctx.import(addr)
      ctx.import(taddr)
      miner = ctx.address
      ctx.mine(101, miner)
      3.times { ctx.fund(addr, 0.001) }
      ctx.mine(1, miner)
      tx = ctx.sibit.pay(250_000, 1000, [skey.priv], taddr, addr, network: :regtest)
      assert_equal(
        250_000, ctx.outputs(tx, ctx.mine(1, miner).first)[taddr],
        'target must receive the exact amount collected from several UTXOs'
      )
    end
  end

  def test_multiple_source_addresses
    in_docker do |ctx|
      keypairs = Array.new(2) { Sibit::Key.generate(network: :regtest) }
      addrs = keypairs.map(&:bech32)
      taddr = Sibit::Key.generate(network: :regtest).bech32
      addrs.each { |a| ctx.import(a) }
      ctx.import(taddr)
      miner = ctx.address
      ctx.mine(101, miner)
      addrs.each { |a| ctx.fund(a, 0.001) }
      ctx.mine(1, miner)
      tx = ctx.sibit.pay(150_000, 1000, keypairs.map(&:priv), taddr, addrs[0], network: :regtest)
      assert_equal(
        150_000, ctx.outputs(tx, ctx.mine(1, miner).first)[taddr],
        'target must receive the funds combined from several addresses'
      )
    end
  end

  def test_output_scripts_match_bitcoin_core
    in_docker do |ctx|
      addrs = [
        ctx.address('legacy'), ctx.address('p2sh-segwit'), ctx.address('bech32'),
        ctx.multisig, ctx.taproot
      ]
      assert_equal(
        addrs.to_h { |a| [a, ctx.script(a)] },
        addrs.to_h { |a| [a, Sibit::Tx::Output.new(1, a, :regtest).script_hex] },
        'our output scripts must match the ones computed by Bitcoin Core'
      )
    end
  end

  def test_pays_to_every_standard_address_type
    in_docker do |ctx|
      key = Sibit::Key.generate(network: :regtest)
      addr = key.bech32
      miner = ctx.address
      ctx.mine(101, miner)
      ctx.import(addr)
      ctx.fund(addr, 0.05)
      ctx.mine(1, miner)
      targets = {
        legacy: ctx.address('legacy'),
        nested: ctx.address('p2sh-segwit'),
        witness: ctx.address('bech32'),
        multisig: ctx.multisig,
        taproot: ctx.taproot
      }
      paid =
        targets.to_h do |kind, target|
          tx = ctx.sibit.pay(300_000, 1000, [key.priv], target, addr, network: :regtest)
          [kind, ctx.outputs(tx, ctx.mine(1, miner).first)[target]]
        end
      assert_equal(
        targets.transform_values { 300_000 }, paid,
        'every standard address type must receive the exact amount'
      )
    end
  end

  def test_pays_to_script_hash_address
    in_docker do |ctx|
      key = Sibit::Key.generate(network: :regtest)
      addr = key.bech32
      miner = ctx.address
      ctx.mine(101, miner)
      ctx.import(addr)
      ctx.fund(addr, 0.01)
      ctx.mine(1, miner)
      target = ctx.address('p2sh-segwit')
      tx = ctx.sibit.pay(300_000, 1000, [key.priv], target, addr, network: :regtest)
      assert_equal(
        { target => 300_000, addr => 699_000 },
        ctx.outputs(tx, ctx.mine(1, miner).first),
        'a script-hash target must receive the amount and the change must come back'
      )
    end
  end

  def test_spends_from_legacy_address
    in_docker do |ctx|
      key = Sibit::Key.generate(network: :regtest)
      addr = key.base58
      miner = ctx.address
      ctx.mine(101, miner)
      ctx.import(addr)
      ctx.fund(addr, 0.01)
      ctx.mine(1, miner)
      target = ctx.address('p2sh-segwit')
      tx = ctx.sibit.pay(300_000, 1000, [key.priv], target, addr, network: :regtest, base58: true)
      assert_equal(
        { target => 300_000, addr => 699_000 },
        ctx.outputs(tx, ctx.mine(1, miner).first),
        'a legacy input must pay the target and return the exact change'
      )
    end
  end

  def test_mixes_legacy_and_witness_inputs
    in_docker do |ctx|
      legacy = Sibit::Key.generate(network: :regtest)
      witness = Sibit::Key.generate(network: :regtest)
      laddr = legacy.base58
      waddr = witness.bech32
      miner = ctx.address
      ctx.mine(101, miner)
      [laddr, waddr].each { |a| ctx.import(a) }
      ctx.fund(laddr, 0.01)
      ctx.fund(waddr, 0.01)
      ctx.mine(1, miner)
      builder = Sibit::TxBuilder.new(:regtest)
      [[laddr, legacy], [waddr, witness]].each do |a, k|
        ctx.api.utxos([a]).each do |u|
          builder.input do |i|
            i.prev_out(u[:hash])
            i.prev_out_index(u[:index])
            i.prev_out_script = u[:script].unpack1('H*')
            i.prev_out_value(u[:value])
            i.signature_key(k)
          end
        end
      end
      target = ctx.address('legacy')
      builder.output(1_500_000, target)
      tx = builder.tx(
        input_value: 2_000_000, leave_fee: true, extra_fee: 5000, change_address: waddr
      )
      ctx.api.push(tx.to_payload.bth)
      assert_equal(
        { target => 1_500_000, waddr => 495_000 },
        ctx.outputs(tx.hash, ctx.mine(1, miner).first),
        'one transaction must spend both a legacy and a witness input'
      )
    end
  end

  def test_sends_change_to_change_address
    in_docker do |ctx|
      key = Sibit::Key.generate(network: :regtest)
      addr = key.bech32
      miner = ctx.address
      ctx.mine(101, miner)
      ctx.import(addr)
      ctx.fund(addr, 0.01)
      ctx.mine(1, miner)
      target = ctx.address('legacy')
      change = ctx.address('p2sh-segwit')
      tx = ctx.sibit.pay(300_000, 1000, [key.priv], target, change, network: :regtest)
      assert_equal(
        { target => 300_000, change => 699_000 },
        ctx.outputs(tx, ctx.mine(1, miner).first),
        'change must go to the change address instead of the source'
      )
    end
  end

  def test_pays_without_change
    in_docker do |ctx|
      key = Sibit::Key.generate(network: :regtest)
      addr = key.bech32
      miner = ctx.address
      ctx.mine(101, miner)
      ctx.import(addr)
      ctx.fund(addr, 0.01)
      ctx.mine(1, miner)
      target = ctx.address('bech32')
      tx = ctx.sibit.pay(999_000, 1000, [key.priv], target, addr, network: :regtest)
      assert_equal(
        { target => 999_000 },
        ctx.outputs(tx, ctx.mine(1, miner).first),
        'a payment that leaves no change must have a single output'
      )
    end
  end

  def test_pays_amount_given_in_btc
    in_docker do |ctx|
      key = Sibit::Key.generate(network: :regtest)
      addr = key.bech32
      miner = ctx.address
      ctx.mine(101, miner)
      ctx.import(addr)
      ctx.fund(addr, 0.01)
      ctx.mine(1, miner)
      target = ctx.address('bech32')
      tx = ctx.sibit.pay('0.003BTC', 1000, [key.priv], target, addr, network: :regtest)
      assert_equal(
        300_000, ctx.outputs(tx, ctx.mine(1, miner).first)[target],
        'an amount given in BTC must arrive as the matching satoshis'
      )
    end
  end

  def test_pays_to_uppercase_address
    in_docker do |ctx|
      key = Sibit::Key.generate(network: :regtest)
      addr = key.bech32
      miner = ctx.address
      ctx.mine(101, miner)
      ctx.import(addr)
      ctx.fund(addr, 0.01)
      ctx.mine(1, miner)
      target = ctx.address('bech32')
      tx = ctx.sibit.pay(300_000, 1000, [key.priv], target.upcase, addr, network: :regtest)
      assert_equal(
        300_000, ctx.outputs(tx, ctx.mine(1, miner).first)[target],
        'an uppercase bech32 target must receive the payment'
      )
    end
  end

  def test_returns_hash_of_confirmed_transaction
    in_docker do |ctx|
      key = Sibit::Key.generate(network: :regtest)
      addr = key.bech32
      miner = ctx.address
      ctx.mine(101, miner)
      ctx.import(addr)
      ctx.fund(addr, 0.01)
      ctx.mine(1, miner)
      tx = ctx.sibit.pay(300_000, 1000, [key.priv], ctx.address, addr, network: :regtest)
      assert_includes(
        ctx.rpc('getblock', [ctx.mine(1, miner).first])['tx'], tx,
        'the returned hash must be the txid found in the block'
      )
    end
  end

  def test_refuses_change_below_dust
    in_docker do |ctx|
      key = Sibit::Key.generate(network: :regtest)
      addr = key.bech32
      miner = ctx.address
      ctx.mine(101, miner)
      ctx.import(addr)
      ctx.fund(addr, 0.01)
      ctx.mine(1, miner)
      target = ctx.address
      assert_raises(Sibit::Error, 'change below the dust limit cannot be accepted') do
        ctx.sibit.pay(998_700, 1000, [key.priv], target, addr, network: :regtest)
      end
    end
  end

  def test_refuses_payment_without_enough_funds
    in_docker do |ctx|
      key = Sibit::Key.generate(network: :regtest)
      addr = key.bech32
      miner = ctx.address
      ctx.mine(101, miner)
      ctx.import(addr)
      ctx.fund(addr, 0.001)
      ctx.mine(1, miner)
      target = ctx.address
      assert_raises(Sibit::Error, 'a payment above the balance cannot be sent') do
        ctx.sibit.pay(500_000, 1000, [key.priv], target, addr, network: :regtest)
      end
    end
  end

  def test_refuses_to_spend_unconfirmed_utxo
    in_docker do |ctx|
      key = Sibit::Key.generate(network: :regtest)
      addr = key.bech32
      miner = ctx.address
      ctx.mine(101, miner)
      ctx.import(addr)
      ctx.fund(addr, 0.01)
      target = ctx.address
      assert_raises(Sibit::Error, 'an unconfirmed UTXO cannot be spent') do
        ctx.sibit.pay(300_000, 1000, [key.priv], target, addr, network: :regtest)
      end
    end
  end

  def test_refuses_address_with_broken_checksum
    in_docker do |ctx|
      key = Sibit::Key.generate(network: :regtest)
      addr = key.bech32
      miner = ctx.address
      ctx.mine(101, miner)
      ctx.import(addr)
      ctx.fund(addr, 0.01)
      ctx.mine(1, miner)
      target = ctx.address('legacy')
      broken = "#{target[0..-2]}#{target[-1] == 'x' ? 'y' : 'x'}"
      assert_raises(Sibit::Error, 'an address with a broken checksum cannot be paid') do
        ctx.sibit.pay(300_000, 1000, [key.priv], broken, addr, network: :regtest)
      end
    end
  end

  private

  def docker?
    system('docker info > /dev/null 2>&1')
  end

  def in_docker(&block)
    skip unless docker?
    require('donce')
    WebMock.allow_net_connect!
    tries = 0
    begin
      tries += 1
      boot(&block)
    rescue RuntimeError => e
      raise unless tries < 5 && e.message.include?('Failed to run docker run')
      retry
    end
  end

  def boot
    port = random_port
    donce(
      image: 'ruimarinho/bitcoin-core:28',
      ports: { port => 18_443 },
      root: true,
      command: [
        '-regtest',
        '-rpcallowip=0.0.0.0/0',
        '-rpcbind=0.0.0.0',
        '-rpcport=18443',
        '-rpcuser=test',
        '-rpcpassword=test',
        '-fallbackfee=0.0001',
        '-deprecatedrpc=create_bdb'
      ].join(' '),
      timeout: 600,
      stdout: Loog::NULL
    ) do |_id|
      host = '127.0.0.1'
      wait_for_rpc(host, port)
      wallet = create_wallet(host, port, "wallet#{rand(99_999)}")
      api = RegtestApi.new(host, port, wallet)
      yield(RegtestContext.new(host, port, wallet, api, Sibit.new(api: api)))
    end
  end

  def random_port
    server = TCPServer.new('127.0.0.1', 0)
    port = server.addr[1]
    server.close
    port
  end

  def wait_for_rpc(host, port, timeout: 30)
    deadline = Time.now + timeout
    err = nil
    loop do
      rpc(host, port, 'getblockchaininfo')
      break
    rescue StandardError => e
      err = e
      raise(StandardError, "Bitcoin RPC not ready in time: #{err.message}") if Time.now > deadline
      sleep(0.5)
    end
  end

  def create_wallet(host, port, name)
    rpc(host, port, 'createwallet', [name, false, false, '', false, false])
    name
  rescue StandardError
    name
  end

  def rpc(host, port, method, params = [], wallet = nil)
    uri = URI("http://#{host}:#{port}")
    uri.path = wallet ? "/wallet/#{wallet}" : '/'
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 30
    req = Net::HTTP::Post.new(uri)
    req.basic_auth('test', 'test')
    req.content_type = 'application/json'
    req.body = JSON.generate(jsonrpc: '1.0', id: 'sibit', method: method, params: params)
    res = http.request(req)
    raise(StandardError, "RPC error: #{res.body}") unless res.is_a?(Net::HTTPSuccess)
    json = JSON.parse(res.body)
    raise(StandardError, "RPC error: #{json['error']}") if json['error']
    json['result']
  end

  # Regtest context for tests.
  #
  # Provides convenient access to Bitcoin Core RPC, Sibit API, and common
  # operations like mining blocks, funding addresses, making addresses of
  # every standard type, and reading back the outputs of a confirmed
  # transaction.
  #
  # Author:: Yegor Bugayenko (yegor256@gmail.com)
  # Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
  # License:: MIT
  class RegtestContext
    attr_reader :api, :sibit

    def initialize(host, port, wallet, api, sibit)
      @host = host
      @port = port
      @wallet = wallet
      @api = api
      @sibit = sibit
    end

    def rpc(method, params = [])
      uri = URI("http://#{@host}:#{@port}/wallet/#{@wallet}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 30
      req = Net::HTTP::Post.new(uri)
      req.basic_auth('test', 'test')
      req.content_type = 'application/json'
      req.body = JSON.generate(jsonrpc: '1.0', id: 'sibit', method: method, params: params)
      res = http.request(req)
      raise(StandardError, "RPC error: #{res.body}") unless res.is_a?(Net::HTTPSuccess)
      json = JSON.parse(res.body)
      raise(StandardError, "RPC error: #{json['error']}") if json['error']
      json['result']
    end

    def address(kind = 'bech32')
      rpc('getnewaddress', ['', kind])
    end

    def multisig
      rpc(
        'addmultisigaddress',
        [2, [address('legacy'), address('legacy')], '', 'bech32']
      )['address']
    end

    def taproot
      rpc(
        'deriveaddresses',
        [rpc('getdescriptorinfo', ["tr(#{Sibit::Key.generate.pub})"])['descriptor']]
      ).first
    end

    def script(addr)
      rpc('validateaddress', [addr])['scriptPubKey']
    end

    def fund(addr, btc)
      rpc('sendtoaddress', [addr, btc])
    end

    def outputs(txid, block)
      rpc('getrawtransaction', [txid, true, block])['vout'].to_h do |out|
        [out['scriptPubKey']['address'], Integer((out['value'] * 100_000_000).round)]
      end
    end

    def mine(count, addr)
      rpc('generatetoaddress', [count, addr])
    end

    def import(addr)
      rpc('importaddress', [addr, '', false])
    rescue StandardError
      nil
    end
  end

  # Regtest API adapter.
  #
  # Author:: Yegor Bugayenko (yegor256@gmail.com)
  # Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
  # License:: MIT
  class RegtestApi
    def initialize(host, port, wallet)
      @host = host
      @port = port
      @wallet = wallet
    end

    def price(_currency = 'USD')
      50_000.0
    end

    def fees
      { S: 1, M: 5, L: 10, XL: 20 }
    end

    def utxos(addresses)
      result = []
      addresses.each do |addr|
        unspent = rpc('listunspent', [0, 9999, [addr]])
        unspent.each do |u|
          result << {
            value: Integer((u['amount'] * 100_000_000).round),
            hash: u['txid'],
            index: u['vout'],
            confirmations: u['confirmations'],
            script: [u['scriptPubKey']].pack('H*')
          }
        end
      end
      result
    end

    def push(hex)
      rpc('sendrawtransaction', [hex])
    end

    private

    def rpc(method, params = [])
      uri = URI("http://#{@host}:#{@port}/wallet/#{@wallet}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 30
      req = Net::HTTP::Post.new(uri)
      req.basic_auth('test', 'test')
      req.content_type = 'application/json'
      req.body = JSON.generate(jsonrpc: '1.0', id: 'sibit', method: method, params: params)
      res = http.request(req)
      raise(Sibit::Error, "RPC error: #{res.body}") unless res.is_a?(Net::HTTPSuccess)
      json = JSON.parse(res.body)
      raise(Sibit::Error, "RPC error: #{json['error']}") if json['error']
      json['result']
    end
  end
end
