# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'iri'
require 'json'
require 'loog'
require 'uri'
require_relative 'error'
require_relative 'http'
require_relative 'json'
require_relative 'version'

# Cryptoapis.io API.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class Sibit
  # Cryptoapis.io API.
  class Cryptoapis
    # Constructor.
    def initialize(key, log: Loog::NULL, http: Sibit::Http.new, dry: false)
      @key = key
      @http = http
      @log = log
      @dry = dry
    end

    # Current price of BTC in USD (float returned).
    def price(_currency = 'USD')
      raise Sibit::NotSupportedError, 'Cryptoapis doesn\'t provide BTC price'
    end

    # Get hash of the block after this one.
    def next_of(hash)
      nxt = Sibit::Json.new(http: @http, log: @log).get(
        Iri.new('https://api.cryptoapis.io/v1/bc/btc/mainnet/blocks').append(hash),
        headers: headers
      )['payload']['hash']
      @log.info("The block #{hash} is the latest, there is no next block") if nxt.nil?
      @log.info("The next block of #{hash} is #{nxt}") unless nxt.nil?
      nxt
    end

    # The height of the block.
    def height(hash)
      json = Sibit::Json.new(http: @http, log: @log).get(
        Iri.new('https://api.cryptoapis.io/v1/bc/btc/mainnet/blocks').append(hash),
        headers: headers
      )['payload']
      h = json['height']
      @log.info("The height of #{hash} is #{h}")
      h
    end

    # Gets the balance of the address, in satoshi.
    def balance(address)
      json = Sibit::Json.new(http: @http, log: @log).get(
        Iri.new('https://api.cryptoapis.io/v1/bc/btc/mainnet/address').append(address),
        headers: headers
      )['payload']
      b = (json['balance'].to_f * 100_000_000).to_i
      @log.info("The balance of #{address} is #{b} satoshi")
      b
    end

    # Get recommended fees, in satoshi per byte.
    def fees
      raise Sibit::NotSupportedError, 'Cryptoapis doesn\'t provide recommended fees'
    end

    # Gets the hash of the latest block.
    def latest
      hash = Sibit::Json.new(http: @http, log: @log).get(
        Iri.new('https://api.cryptoapis.io/v1/bc/btc/mainnet/blocks/latest'),
        headers: headers
      )['payload']['hash']
      @log.info("The latest block hash is #{hash}")
      hash
    end

    # Fetch all unspent outputs per address.
    def utxos(_sources)
      raise Sibit::NotSupportedError, 'Not implemented yet'
    end

    # Push this transaction (in hex format) to the network.
    def push(hex)
      Sibit::Json.new(http: @http, log: @log).post(
        Iri.new('https://api.cryptoapis.io/v1/bc/btc/testnet/txs/send'),
        JSON.pretty_generate(hex: hex),
        headers: headers
      )
    end

    # This method should fetch a Blockchain block and return as a hash.
    def block(hash)
      head = Sibit::Json.new(http: @http, log: @log).get(
        Iri.new('https://api.cryptoapis.io/v1/bc/btc/mainnet/blocks').append(hash),
        headers: headers
      )['payload']
      {
        provider: self.class.name,
        hash: head['hash'],
        orphan: false,
        next: head['nextblockhash'],
        previous: head['previousblockhash'],
        txns: txns(hash)
      }
    end

    private

    def headers
      return {} if @key.nil? || @key.empty?
      {
        'X-API-Key': @key
      }
    end

    def txns(hash)
      index = 0
      limit = 200
      all = []
      loop do
        txns = Sibit::Json.new(http: @http, log: @log).get(
          Iri.new('https://api.cryptoapis.io/v1/bc/btc/mainnet/txs/block/')
            .append(hash).add(index: index, limit: limit),
          headers: headers
        )['payload'].map do |t|
          {
            hash: t['hash'],
            outputs: t['txouts'].map do |o|
              {
                address: o['addresses'][0],
                value: o['amount'].to_f * 100_000_000
              }
            end
          }
        end
        all += txns
        index += txns.length
        break if txns.length < limit
      end
      all
    end
  end
end
