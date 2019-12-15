# frozen_string_literal: true

# Copyright (c) 2019 Yegor Bugayenko
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
require_relative 'version'
require_relative 'error'
require_relative 'log'
require_relative 'http'
require_relative 'json'

# Btc.com API.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019 Yegor Bugayenko
# License:: MIT
class Sibit
  # Btc.com API.
  class Btc
    # Constructor.
    def initialize(log: Sibit::Log.new, http: Sibit::Http.new, dry: false)
      @http = http
      @log = log
      @dry = dry
    end

    # Current price of BTC in USD (float returned).
    def price(_currency)
      raise Sibit::Error, 'Not implemented yet'
    end

    # Gets the balance of the address, in satoshi.
    def balance(address)
      uri = URI("https://chain.api.btc.com/v3/address/#{address}/unspent")
      json = Sibit::Json.new(http: @http, log: @log).get(uri)
      txns = json['data']['list']
      balance = txns.map { |tx| tx['value'] }.inject(&:+) || 0
      @log.info("The balance of #{address} is #{balance}, total txns: #{txns.count}")
      balance
    end

    # Get recommended fees, in satoshi per byte.
    def fees
      raise Sibit::Error, 'Not implemented yet'
    end

    # Sends a payment and returns the transaction hash.
    def pay(_amount, _fee, _sources, _target, _change)
      raise Sibit::Error, 'Not implemented yet'
    end

    # Gets the hash of the latest block.
    def latest
      uri = URI('https://chain.api.btc.com/v3/block/latest')
      json = Sibit::Json.new(http: @http, log: @log).get(uri)
      hash = json['data']['hash']
      @log.info("The hash of the latest block is #{hash}")
      hash
    end
  end
end
