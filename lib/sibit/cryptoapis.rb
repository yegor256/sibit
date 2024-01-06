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

require 'iri'
require 'json'
require 'uri'
require_relative 'error'
require_relative 'http'
require_relative 'json'
require_relative 'log'
require_relative 'version'

# Cryptoapis.io API.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2024 Yegor Bugayenko
# License:: MIT
class Sibit
  # Btc.com API.
  class Cryptoapis
    # Constructor.
    def initialize(key, log: Sibit::Log.new, http: Sibit::Http.new, dry: false)
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
