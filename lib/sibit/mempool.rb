# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'iri'
require 'json'
require 'loog'
require 'uri'
require_relative 'error'
require_relative 'http'
require_relative 'json'
require_relative 'version'

# Mempool.space API.
#
# It works through the open-source Esplora API, which needs no key:
# https://mempool.space/docs/api/rest
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class Sibit::Mempool
  # Constructor.
  def initialize(log: Loog::NULL, http: Sibit::Http.new)
    @http = http
    @log = log
  end

  # Current price of BTC in the currency (float returned).
  def price(currency = 'USD')
    p = Sibit::Json.new(http: @http, log: @log).get(Iri.new('https://mempool.space/api/v1/prices'))[currency]
    raise(Sibit::Error, "The price of BTC in #{currency} is absent at Mempool") if p.nil?
    @log.debug("The price of BTC is #{p} #{currency}")
    Float(p)
  end

  # Gets the balance of the address, in satoshi.
  def balance(address)
    stats = Sibit::Json.new(http: @http, log: @log).get(
      Iri.new('https://mempool.space/api/address').append(address)
    )['chain_stats']
    raise(Sibit::Error, "The balance of #{address} is absent at Mempool") if stats.nil?
    b = stats['funded_txo_sum'] - stats['spent_txo_sum']
    @log.debug("The balance of #{address} is #{b} satoshi")
    b
  end

  # Get hash of the block after this one, or NIL if it's the last one in Blockchain.
  def next_of(hash)
    nxt = status(hash)['next_best']
    @log.debug("At Mempool the block #{hash} is the latest, there is no next block") if nxt.nil?
    @log.debug("The next block of #{hash} is #{nxt}") unless nxt.nil?
    nxt
  end

  # The height of the block.
  def height(hash)
    h = head(hash)['height']
    raise(Sibit::Error, "The block #{hash} found but the height is absent") if h.nil?
    @log.debug("The height of #{hash} is #{h}")
    h
  end

  # Get recommended fees, in satoshi per byte.
  def fees
    json = Sibit::Json.new(http: @http, log: @log).get(Iri.new('https://mempool.space/api/v1/fees/recommended'))
    @log.debug(
      "Currently recommended Bitcoin fees at Mempool: #{json['economyFee']}/#{json['hourFee']}/" \
      "#{json['halfHourFee']}/#{json['fastestFee']} sat/vbyte"
    )
    { S: json['economyFee'], M: json['hourFee'], L: json['halfHourFee'], XL: json['fastestFee'] }
  end

  # Gets the hash of the latest block.
  def latest
    hash = Sibit::Json.new(http: @http, log: @log).get(Iri.new('https://mempool.space/api/blocks'))[0]&.dig('id')
    raise(Sibit::Error, 'The latest block not found at Mempool') if hash.nil?
    @log.debug("The hash of the latest block is #{hash}")
    hash
  end

  # Fetch all unspent outputs per address.
  def utxos(sources)
    tip = Sibit::Json.new(http: @http, log: @log).get(Iri.new('https://mempool.space/api/blocks/tip/height'))
    sources.flat_map do |address|
      Sibit::Json.new(http: @http, log: @log).get(
        Iri.new('https://mempool.space/api/address').append(address).append('utxo')
      ).map do |u|
        out = Sibit::Json.new(http: @http, log: @log).get(
          Iri.new('https://mempool.space/api/tx').append(u['txid'])
        )['vout'][u['vout']]
        raise(Sibit::Error, "The output #{u['vout']} of #{u['txid']} is absent") if out.nil?
        {
          value: u['value'],
          hash: u['txid'],
          index: u['vout'],
          confirmations: u['status']['confirmed'] ? tip - u['status']['block_height'] + 1 : 0,
          script: [out['scriptpubkey']].pack('H*')
        }
      end
    end
  end

  # Push this transaction (in hex format) to the network.
  def push(hex)
    Sibit::Json.new(http: @http, log: @log).post(
      Iri.new('https://mempool.space/api/tx'), hex, headers: { 'Content-Type' => 'text/plain' }
    )
    @log.debug("Transaction (#{hex.length} in hex) has been pushed to Mempool")
  end

  # This method should fetch a Blockchain block and return as a hash.
  def block(hash)
    json = head(hash)
    s = status(hash)
    {
      provider: self.class.name,
      hash: json['id'],
      orphan: !s['in_best_chain'],
      next: s['next_best'],
      previous: json['previousblockhash'],
      txns: (0...json['tx_count']).step(25).flat_map do |start|
        Sibit::Json.new(http: @http, log: @log).get(
          Iri.new('https://mempool.space/api/block').append(hash).append('txs').append(start.to_s)
        ).map do |t|
          {
            hash: t['txid'],
            outputs: t['vout'].map { |o| { address: o['scriptpubkey_address'], value: o['value'] } }
          }
        end
      end
    }
  end

  private

  def head(hash)
    Sibit::Json.new(http: @http, log: @log).get(Iri.new('https://mempool.space/api/block').append(hash))
  end

  def status(hash)
    Sibit::Json.new(http: @http, log: @log).get(
      Iri.new('https://mempool.space/api/block').append(hash).append('status')
    )
  end
end
