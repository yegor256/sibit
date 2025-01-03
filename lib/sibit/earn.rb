# frozen_string_literal: true

# Copyright (c) 2019-2025 Yegor Bugayenko
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
require_relative 'version'

# Earn.com API.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class Sibit
  # Blockchain.info API.
  class Earn
    # Constructor.
    def initialize(log: Sibit::Log.new, http: Sibit::Http.new, dry: false)
      @http = http
      @log = log
      @dry = dry
    end

    # Current price of BTC in USD (float returned).
    def price(_currency)
      raise Sibit::NotSupportedError, 'price() doesn\'t work here'
    end

    # Gets the balance of the address, in satoshi.
    def balance(_address)
      raise Sibit::NotSupportedError, 'balance() doesn\'t work here'
    end

    # Get hash of the block after this one.
    def next_of(_hash)
      raise Sibit::NotSupportedError, 'Earn.com API doesn\'t provide next_of()'
    end

    # The height of the block.
    def height(_hash)
      raise Sibit::NotSupportedError, 'Earn API doesn\'t provide height()'
    end

    # Get recommended fees, in satoshi per byte. The method returns
    # a hash: { S: 12, M: 45, L: 100, XL: 200 }
    def fees
      json = Sibit::Json.new(http: @http, log: @log).get(
        Iri.new('https://bitcoinfees.earn.com/api/v1/fees/recommended')
      )
      @log.info("Current recommended Bitcoin fees: \
#{json['hourFee']}/#{json['halfHourFee']}/#{json['fastestFee']} sat/byte")
      {
        S: json['hourFee'] / 3,
        M: json['hourFee'],
        L: json['halfHourFee'],
        XL: json['fastestFee']
      }
    end

    # Fetch all unspent outputs per address.
    def utxos(_sources)
      raise Sibit::NotSupportedError, 'Not implemented yet'
    end

    # Push this transaction (in hex format) to the network.
    def push(_hex)
      raise Sibit::NotSupportedError, 'Not implemented yet'
    end

    # Gets the hash of the latest block.
    def latest
      raise Sibit::NotSupportedError, 'latest() doesn\'t work here'
    end

    # This method should fetch a Blockchain block and return as a hash.
    def block(_hash)
      raise Sibit::NotSupportedError, 'block() doesn\'t work here'
    end
  end
end
