# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'bitcoin'
require 'iri'
require 'json'
require 'uri'
require_relative 'error'
require_relative 'http'
require_relative 'json'
require_relative 'version'

# Blockchain.info API.
#
# It works through the Blockchain API:
# https://www.blockchain.com/api/blockchain_api
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class Sibit
  # Blockchain.info API.
  class Blockchain
    # Constructor.
    def initialize(log: Sibit::Log.new, http: Sibit::Http.new, dry: false)
      @http = http
      @log = log
      @dry = dry
    end

    # Current price of BTC in USD (float returned).
    def price(currency = 'USD')
      h = Sibit::Json.new(http: @http, log: @log).get(
        Iri.new('https://blockchain.info/ticker')
      )[currency]
      raise Error, "Unrecognized currency #{currency}" if h.nil?
      price = h['15m']
      @log.info("The price of BTC is #{price} USD")
      price
    end

    # Get hash of the block after this one.
    def next_of(_hash)
      raise Sibit::NotSupportedError, 'next_of() in Blockchain API is broken, always returns NULL'
      # json = Sibit::Json.new(http: @http, log: @log).get(
      #   Iri.new('https://blockchain.info/rawblock').append(hash)
      # )
      # nxt = json['next_block'][0]
      # if nxt.nil?
      #   @log.info("There is no block after #{hash}")
      # else
      #   @log.info("The next block of #{hash} is #{nxt}")
      # end
      # nxt
    end

    # The height of the block.
    def height(hash)
      json = Sibit::Json.new(http: @http, log: @log).get(
        Iri.new('https://blockchain.info/rawblock').append(hash)
      )
      h = json['height']
      @log.info("The height of #{hash} is #{h}")
      h
    end

    # Gets the balance of the address, in satoshi.
    def balance(address)
      json = Sibit::Json.new(http: @http, log: @log).get(
        Iri.new('https://blockchain.info/rawaddr').append(address).add(limit: 0),
        accept: [200, 500]
      )
      b = json['final_balance']
      @log.info("The balance of #{address} is #{b} satoshi (#{json['n_tx']} txns)")
      b
    end

    # Get recommended fees.
    def fees
      json = Sibit::Json.new(http: @http, log: @log).get(
        Iri.new('https://api.blockchain.info/mempool/fees')
      )
      @log.info("Current recommended Bitcoin fees: \
      #{json['regular']}/#{json['priority']}/#{json['limits']['max']} sat/byte")
      {
        S: json['regular'] / 3,
        M: json['regular'],
        L: json['priority'],
        XL: json['limits']['max']
      }
    end

    # Fetch all unspent outputs per address. The argument is an array
    # of Bitcoin addresses.
    def utxos(sources)
      Sibit::Json.new(http: @http, log: @log).get(
        Iri.new('https://blockchain.info/unspent').add(active: sources.join('|'), limit: 1000)
      )['unspent_outputs'].map do |u|
        {
          value: u['value'],
          hash: u['tx_hash_big_endian'],
          index: u['tx_output_n'],
          confirmations: u['confirmations'],
          script: [u['script']].pack('H*')
        }
      end
    end

    # Push this transaction (in hex format) to the network.
    def push(hex)
      return if @dry
      Sibit::Json.new(http: @http, log: @log).post(
        Iri.new('https://blockchain.info/pushtx'),
        hex
      )
    end

    # Gets the hash of the latest block.
    def latest
      hash = Sibit::Json.new(http: @http, log: @log).get(
        Iri.new('https://blockchain.info/latestblock')
      )['hash']
      @log.info("The latest block hash is #{hash}")
      hash
    end

    # This method should fetch a Blockchain block and return as a hash.
    def block(hash)
      json = Sibit::Json.new(http: @http, log: @log).get(
        Iri.new('https://blockchain.info/rawblock').append(hash)
      )
      {
        provider: self.class.name,
        hash: json['hash'],
        orphan: !json['main_chain'],
        next: json['next_block'][0],
        previous: json['prev_block'],
        txns: json['tx'].map do |t|
          {
            hash: t['hash'],
            outputs: t['out'].map do |o|
              {
                address: o['addr'],
                value: o['value']
              }
            end
          }
        end
      }
    end
  end
end
