# frozen_string_literal: true

# Copyright (c) 2019-2020 Yegor Bugayenko
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
require 'json'
require 'uri'
require_relative 'version'
require_relative 'error'
require_relative 'http'
require_relative 'json'

# Blockchain.info API.
#
# It works through the Blockchain API:
# https://www.blockchain.com/api/blockchain_api
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2020 Yegor Bugayenko
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
    def price(currency)
      h = Sibit::Json.new(http: @http, log: @log).get(
        URI('https://blockchain.info/ticker')
      )[currency]
      raise Error, "Unrecognized currency #{currency}" if h.nil?
      price = h['15m']
      @log.info("The price of BTC is #{price} USD")
      price
    end

    # Gets the balance of the address, in satoshi.
    def balance(address)
      json = Sibit::Json.new(http: @http, log: @log).get(
        URI("https://blockchain.info/rawaddr/#{address}")
      )
      @log.info("Total transactions: #{json['n_tx']}")
      @log.info("Received/sent: #{json['total_received']}/#{json['total_sent']}")
      json['final_balance']
    end

    # Get recommended fees.
    def fees
      raise Sibit::Error, 'fees() not implemented yet'
    end

    # Fetch all unspent outputs per address.
    def utxos(sources)
      Sibit::Json.new(http: @http, log: @log).get(
        URI("https://blockchain.info/unspent?active=#{sources.keys.join('|')}&limit=1000")
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
        URI('https://blockchain.info/pushtx'),
        hex
      )
    end

    # Gets the hash of the latest block.
    def latest
      hash = Sibit::Json.new(http: @http, log: @log).get(
        URI('https://blockchain.info/latestblock')
      )['hash']
      @log.info("The latest block hash is #{hash}")
      hash
    end

    # This method should fetch a Blockchain block and return as a hash.
    def block(hash)
      json = Sibit::Json.new(http: @http, log: @log).get(
        URI("https://blockchain.info/rawblock/#{hash}")
      )
      {
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
