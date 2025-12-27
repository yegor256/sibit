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

# Cex.io API.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class Sibit
  # Cex.io API.
  class Cex
    # Constructor.
    def initialize(log: Loog::NULL, http: Sibit::Http.new, dry: false)
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

    # This method should fetch a Blockchain block and return as a hash.
    def block(_hash)
      raise Sibit::NotSupportedError, 'Cex.io doesn\'t implement block()'
    end
  end
end
