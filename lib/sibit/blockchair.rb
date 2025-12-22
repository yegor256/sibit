# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'cgi'
require 'iri'
require 'json'
require 'uri'
require_relative 'error'
require_relative 'http'
require 'loog'
require_relative 'json'
require_relative 'version'

# Blockchair.com API.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
# License:: MIT
class Sibit
  # Btc.com API.
  class Blockchair
    # Constructor.
    def initialize(key: nil, log: Loog::NULL, http: Sibit::Http.new, dry: false)
      @key = key
      @http = http
      @log = log
      @dry = dry
    end

    # Current price of BTC in USD (float returned).
    def price(_currency = 'USD')
      raise Sibit::NotSupportedError, 'Blockchair doesn\'t provide BTC price'
    end

    # The height of the block.
    def height(_hash)
      raise Sibit::NotSupportedError, 'Blockchair API doesn\'t provide height()'
    end

    # Get hash of the block after this one.
    def next_of(_hash)
      # They don't provide next block hash
      raise Sibit::NotSupportedError, 'Blockchair API doesn\'t provide next_of()'
    end

    # Gets the balance of the address, in satoshi.
    def balance(address)
      json = Sibit::Json.new(http: @http, log: @log).get(
        Iri.new('https://api.blockchair.com/bitcoin/dashboards/address').append(address).fragment(the_key)
      )['data'][address]
      if json.nil?
        @log.info("Address #{address} not found")
        return 0
      end
      a = json['address']
      b = a['balance']
      @log.info("The balance of #{address} is #{b} satoshi")
      b
    end

    # Get recommended fees, in satoshi per byte.
    def fees
      raise Sibit::NotSupportedError, 'Blockchair doesn\'t implement fees()'
    end

    # Gets the hash of the latest block.
    def latest
      raise Sibit::NotSupportedError, 'Blockchair doesn\'t implement latest()'
    end

    # Fetch all unspent outputs per address.
    def utxos(_sources)
      raise Sibit::NotSupportedError, 'Blockchair doesn\'t implement utxos()'
    end

    # Push this transaction (in hex format) to the network.
    def push(hex)
      Sibit::Json.new(http: @http, log: @log).post(
        Iri.new('https://api.blockchair.com/bitcoin/push/transaction').fragment(the_key),
        "data=#{hex}"
      )
      @log.info("Transaction (#{hex.length} in hex) has been pushed to Blockchair")
    end

    # This method should fetch a Blockchain block and return as a hash.
    def block(_hash)
      raise Sibit::NotSupportedError, 'Blockchair doesn\'t implement block()'
    end

    private

    def the_key
      @key.nil? ? '' : "key=#{CGI.escape(@key)}"
    end
  end
end
