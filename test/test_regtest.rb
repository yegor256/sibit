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
      balance = ctx.rpc('getbalance')
      assert_operator(balance, :>, 0, 'wallet must have balance after mining')
      target = ctx.address
      privkey = ctx.rpc('dumpprivkey', [addr])
      utxos = ctx.rpc('listunspent', [1, 9999, [addr]])
      refute_empty(utxos, 'must have UTXOs to spend')
      tx = ctx.sibit.pay(10_000, 1000, [privkey], target, addr, network: :regtest)
      refute_nil(tx, 'transaction hash must not be nil')
      assert_match(/^[0-9a-f]{64}$/, tx, 'transaction hash format is invalid')
      ctx.mine(1, addr)
      received = ctx.rpc('listunspent', [1, 9999, [target]])
      refute_empty(received, 'target must have received payment')
      amount = (received.first['amount'] * 100_000_000).to_i
      assert_equal(10_000, amount, 'target must receive exactly 10000 satoshis')
    end
  end

  def test_sibit_generated_keys_send_payment
    in_docker do |ctx|
      key = Sibit::Key.generate(network: :regtest)
      priv = key.priv
      addr = key.bech32
      refute_nil(addr, 'generated address must not be nil')
      assert_match(/^bcrt1/, addr, 'regtest address must start with bcrt1')
      miner = ctx.address
      ctx.mine(101, miner)
      ctx.import(addr)
      fund = ctx.rpc('sendtoaddress', [addr, 0.001])
      refute_nil(fund, 'funding transaction must not be nil')
      ctx.mine(1, miner)
      utxos = ctx.api.utxos([addr])
      refute_empty(utxos, 'funded address must have UTXOs')
      target = ctx.address
      tx = ctx.sibit.pay(50_000, 1000, [priv], target, addr, network: :regtest)
      refute_nil(tx, 'payment transaction must not be nil')
      assert_match(/^[0-9a-f]{64}$/, tx, 'transaction hash format is invalid')
      ctx.mine(1, miner)
      received = ctx.rpc('listunspent', [1, 9999, [target]])
      refute_empty(received, 'target must have received payment from sibit key')
    end
  end

  def test_multihop_payment_chain
    in_docker do |ctx|
      keypairs = Array.new(3) { Sibit::Key.generate(network: :regtest) }
      keys = keypairs.map(&:priv)
      addrs = keypairs.map(&:bech32)
      addrs.each do |a|
        assert_match(/^bcrt1/, a, 'each address must be valid regtest bech32')
        ctx.import(a)
      end
      miner = ctx.address
      ctx.mine(101, miner)
      ctx.rpc('sendtoaddress', [addrs[0], 0.01])
      ctx.mine(1, miner)
      tx1 = ctx.sibit.pay(500_000, 1000, [keys[0]], addrs[1], addrs[0], network: :regtest)
      refute_nil(tx1, 'first hop transaction must succeed')
      ctx.mine(1, miner)
      tx2 = ctx.sibit.pay(400_000, 1000, [keys[1]], addrs[2], addrs[1], network: :regtest)
      refute_nil(tx2, 'second hop transaction must succeed')
      ctx.mine(1, miner)
      utxos = ctx.api.utxos([addrs[2]])
      refute_empty(utxos, 'final address must have funds after chain')
      total = utxos.sum { |u| u[:value] }
      assert_equal(400_000, total, 'final address must have expected amount')
    end
  end

  def test_roundtrip_payment
    in_docker do |ctx|
      akey = Sibit::Key.generate(network: :regtest)
      bkey = Sibit::Key.generate(network: :regtest)
      alice = akey.priv
      bob = bkey.priv
      aaddr = akey.bech32
      baddr = bkey.bech32
      ctx.import(aaddr)
      ctx.import(baddr)
      miner = ctx.address
      ctx.mine(101, miner)
      ctx.rpc('sendtoaddress', [aaddr, 0.01])
      ctx.mine(1, miner)
      tx1 = ctx.sibit.pay(500_000, 1000, [alice], baddr, aaddr, network: :regtest)
      refute_nil(tx1, 'alice to bob must succeed')
      ctx.mine(1, miner)
      tx2 = ctx.sibit.pay(400_000, 1000, [bob], aaddr, baddr, network: :regtest)
      refute_nil(tx2, 'bob to alice must succeed')
      ctx.mine(1, miner)
      utxos = ctx.api.utxos([aaddr])
      refute_empty(utxos, 'alice must have funds after roundtrip')
      received = utxos.find { |u| u[:value] == 400_000 }
      refute_nil(received, 'alice must receive 400000 satoshis from bob')
    end
  end

  def test_multiple_inputs_from_same_address
    in_docker do |ctx|
      skey = Sibit::Key.generate(network: :regtest)
      tkey = Sibit::Key.generate(network: :regtest)
      priv = skey.priv
      addr = skey.bech32
      taddr = tkey.bech32
      ctx.import(addr)
      ctx.import(taddr)
      miner = ctx.address
      ctx.mine(101, miner)
      3.times { ctx.rpc('sendtoaddress', [addr, 0.001]) }
      ctx.mine(1, miner)
      utxos = ctx.api.utxos([addr])
      assert_equal(3, utxos.count, 'address must have three separate UTXOs')
      tx = ctx.sibit.pay(250_000, 1000, [priv], taddr, addr, network: :regtest)
      refute_nil(tx, 'spending multiple UTXOs must succeed')
      ctx.mine(1, miner)
      received = ctx.api.utxos([taddr])
      refute_empty(received, 'target must receive funds from multiple inputs')
    end
  end

  def test_multiple_source_addresses
    in_docker do |ctx|
      keypairs = Array.new(2) { Sibit::Key.generate(network: :regtest) }
      keys = keypairs.map(&:priv)
      addrs = keypairs.map(&:bech32)
      tkey = Sibit::Key.generate(network: :regtest)
      taddr = tkey.bech32
      addrs.each { |a| ctx.import(a) }
      ctx.import(taddr)
      miner = ctx.address
      ctx.mine(101, miner)
      addrs.each { |a| ctx.rpc('sendtoaddress', [a, 0.001]) }
      ctx.mine(1, miner)
      tx = ctx.sibit.pay(150_000, 1000, keys, taddr, addrs[0], network: :regtest)
      refute_nil(tx, 'spending from multiple addresses must succeed')
      ctx.mine(1, miner)
      received = ctx.api.utxos([taddr])
      refute_empty(received, 'target must receive combined funds')
      total = received.sum { |u| u[:value] }
      assert_equal(150_000, total, 'target must receive exact amount')
    end
  end

  private

  def docker?
    system('docker info > /dev/null 2>&1')
  end

  def in_docker
    skip unless docker?
    require 'donce'
    WebMock.allow_net_connect!
    port = random_port
    donce(
      image: 'ruimarinho/bitcoin-core:latest',
      ports: { port => 18_443 },
      root: true,
      command: [
        '-regtest',
        '-rpcallowip=0.0.0.0/0',
        '-rpcbind=0.0.0.0',
        '-rpcport=18443',
        '-rpcuser=test',
        '-rpcpassword=test',
        '-fallbackfee=0.0001'
      ].join(' '),
      timeout: 600,
      log: Loog::NULL
    ) do |_id|
      host = '127.0.0.1'
      wait_for_rpc(host, port)
      wallet = create_wallet(host, port, "wallet#{rand(99_999)}")
      api = RegtestApi.new(host, port, wallet)
      sibit = Sibit.new(api: api)
      ctx = RegtestContext.new(host, port, wallet, api, sibit)
      yield ctx
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
      raise "Bitcoin RPC not ready in time: #{err.message}" if Time.now > deadline
      sleep 0.5
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
    raise "RPC error: #{res.body}" unless res.is_a?(Net::HTTPSuccess)
    json = JSON.parse(res.body)
    raise "RPC error: #{json['error']}" if json['error']
    json['result']
  end

  # Regtest context for tests.
  #
  # Provides convenient access to Bitcoin Core RPC, Sibit API, and common
  # operations like mining blocks and importing addresses.
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
      raise "RPC error: #{res.body}" unless res.is_a?(Net::HTTPSuccess)
      json = JSON.parse(res.body)
      raise "RPC error: #{json['error']}" if json['error']
      json['result']
    end

    def address
      rpc('getnewaddress', ['', 'bech32'])
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
        unspent = rpc('listunspent', [1, 9999, [addr]])
        unspent.each do |u|
          result << {
            value: (u['amount'] * 100_000_000).to_i,
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
      raise Sibit::Error, "RPC error: #{res.body}" unless res.is_a?(Net::HTTPSuccess)
      json = JSON.parse(res.body)
      raise Sibit::Error, "RPC error: #{json['error']}" if json['error']
      json['result']
    end
  end
end
