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

require 'uri'
require 'json'
require 'cgi'
require_relative 'version'
require_relative 'error'
require_relative 'log'
require_relative 'http'
require_relative 'json'

# Blockchair.com API.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2020 Yegor Bugayenko
# License:: MIT
class Sibit
  # Btc.com API.
  class Blockchair
    # Constructor.
    def initialize(key: nil, log: Sibit::Log.new, http: Sibit::Http.new, dry: false)
      @key = key
      @http = http
      @log = log
      @dry = dry
    end

    # Current price of BTC in USD (float returned).
    def price(_currency)
      raise Sibit::Error, 'Blockchair doesn\'t provide BTC price'
    end

    # Gets the balance of the address, in satoshi.
    def balance(address)
      json = Sibit::Json.new(http: @http, log: @log).get(
        URI("https://api.blockchair.com/bitcoin/dashboards/address/#{address}?#{the_key}")
      )['data'][address]
      raise Sibit::Error, "Address #{address} not found" if json.nil?
      b = json['address']['balance']
      @log.info("The balance of #{address} is #{b} satoshi")
      b
    end

    # Get recommended fees, in satoshi per byte.
    def fees
      raise Sibit::Error, 'Not implemented yet'
    end

    # Gets the hash of the latest block.
    def latest
      raise Sibit::Error, 'Not implemented yet'
    end

    # Fetch all unspent outputs per address.
    def utxos(_sources)
      raise Sibit::Error, 'Not implemented yet'
    end

    # Push this transaction (in hex format) to the network.
    def push(hex)
      Sibit::Json.new(http: @http, log: @log).post(
        URI("https://api.blockchair.com/bitcoin/push/transaction?#{the_key}"),
        "data=#{hex}"
      )
    end

    # This method should fetch a Blockchain block and return as a hash.
    def block(_hash)
      raise Sibit::Error, 'Not implemented yet'
    end

    private

    def the_key
      @key.nil? ? '' : "key=#{CGI.escape(@key)}"
    end
  end
end
