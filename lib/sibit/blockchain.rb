# frozen_string_literal: true

# Copyright (c) 2019-2024 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

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
# Copyright:: Copyright (c) 2019-2024 Yegor Bugayenko
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
