# frozen_string_literal: true

# Copyright (c) 2019-2023 Yegor Bugayenko
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

require 'uri'
require 'json'
require_relative 'error'
require_relative 'log'
require_relative 'http'
require_relative 'json'

# Cex.io API.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2023 Yegor Bugayenko
# License:: MIT
class Sibit
  # Btc.com API.
  class Cex
    # Constructor.
    def initialize(log: Sibit::Log.new, http: Sibit::Http.new, dry: false)
      @http = http
      @log = log
      @dry = dry
    end

    # Current price of BTC in USD (float returned).
    def price(currency = 'USD')
      json = Sibit::Json.new(http: @http, log: @log).get(
        Iri.new('https://cex.io/api/last_price/BTC').append(currency)
      )
      p = json['lprice'].to_f
      @log.info("The price of BTC is #{p} #{currency}")
      p
    end

    # Get hash of the block after this one.
    def next_of(_hash)
      raise Sibit::NotSupportedError, 'Cex.io API doesn\'t provide next_of()'
    end

    # Gets the balance of the address, in satoshi.
    def balance(_address)
      raise Sibit::NotSupportedError, 'Cex.io doesn\'t implement balance()'
    end

    # The height of the block.
    def height(_hash)
      raise Sibit::NotSupportedError, 'Cex.io doesn\'t implement height()'
    end

    # Get recommended fees, in satoshi per byte.
    def fees
      raise Sibit::NotSupportedError, 'Cex.io doesn\'t implement fees()'
    end

    # Gets the hash of the latest block.
    def latest
      raise Sibit::NotSupportedError, 'Cex.io doesn\'t implement latest()'
    end

    # Fetch all unspent outputs per address.
    def utxos(_sources)
      raise Sibit::NotSupportedError, 'Cex.io doesn\'t implement utxos()'
    end

    # Push this transaction (in hex format) to the network.
    def push(_hex)
      raise Sibit::NotSupportedError, 'Cex.io doesn\'t implement push()'
    end

    def block(_hash)
      raise Sibit::NotSupportedError, 'Cex.io doesn\'t implement block()'
    end
  end
end
