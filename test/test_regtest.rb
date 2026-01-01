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
      wallet = create_wallet(host, port, 'testwallet')
      addr = rpc(host, port, 'getnewaddress', ['', 'legacy'], wallet)
      rpc(host, port, 'generatetoaddress', [101, addr], wallet)
      balance = rpc(host, port, 'getbalance', [], wallet)
      assert_operator(balance, :>, 0, 'wallet must have balance after mining')
      target = rpc(host, port, 'getnewaddress', ['', 'legacy'], wallet)
      privkey = rpc(host, port, 'dumpprivkey', [addr], wallet)
      utxos = rpc(host, port, 'listunspent', [1, 9999, [addr]], wallet)
      refute_empty(utxos, 'must have UTXOs to spend')
      api = RegtestApi.new(host, port, wallet)
      sibit = Sibit.new(api: api)
      tx = sibit.pay(10_000, 1000, [privkey], target, addr)
      refute_nil(tx, 'transaction hash must not be nil')
      assert_match(/^[0-9a-f]{64}$/, tx, 'transaction hash format is invalid')
    end
  end

  private

  def docker?
    system('docker info > /dev/null 2>&1')
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
