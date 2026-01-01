# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'iri'
require 'json'
require 'loog'
require 'uri'
require_relative 'error'
require_relative 'http'
require_relative 'json'
require_relative 'version'

# Bitcoinchain.com API.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class Sibit::Bitcoinchain
  # Constructor.
  def initialize(log: Loog::NULL, http: Sibit::Http.new)
    @http = http
    @log = log
  end

  # Current price of BTC in USD (float returned).
  def price(_currency = 'USD')
    raise Sibit::NotSupportedError, 'Bitcoinchain API doesn\'t provide BTC price'
  end

  # The height of the block.
  def height(_hash)
    raise Sibit::NotSupportedError, 'Bitcoinchain API doesn\'t provide height()'
  end

  # Get hash of the block after this one.
  def next_of(hash)
    block = Sibit::Json.new(http: @http, log: @log).get(
      Iri.new('https://api-r.bitcoinchain.com/v1/block').append(hash)
    )[0]
    raise Sibit::Error, "Block #{hash} not found" if block.nil?
    nxt = block['next_block']
    nxt = nil if nxt == '0000000000000000000000000000000000000000000000000000000000000000'
    @log.debug("The block #{hash} is the latest, there is no next block") if nxt.nil?
    @log.debug("The next block of #{hash} is #{nxt}") unless nxt.nil?
    nxt
  end

  # Gets the balance of the address, in satoshi.
  def balance(address)
    json = Sibit::Json.new(http: @http, log: @log).get(
      Iri.new('https://api-r.bitcoinchain.com/v1/address').append(address),
      accept: [200, 409]
    )[0]
    b = json['balance']
    if b.nil?
      @log.debug("The balance of #{address} is not visible")
      return 0
    end
    b *= 100_000_000
    b = b.to_i
    @log.debug("The balance of #{address} is #{b} satoshi (#{json['transactions']} txns)")
    b
  end

  # Get recommended fees, in satoshi per byte.
  def fees
    raise Sibit::NotSupportedError, 'Not implemented yet'
  end

  # Gets the hash of the latest block.
  def latest
    hash = Sibit::Json.new(http: @http, log: @log).get(
      Iri.new('https://api-r.bitcoinchain.com/v1/status')
    )['hash']
    @log.debug("The latest block hash is #{hash}")
    hash
  end

  # Fetch all unspent outputs per address.
  def utxos(_sources)
    raise Sibit::NotSupportedError, 'Not implemented yet'
  end

  # Push this transaction (in hex format) to the network.
  def push(_hex)
    raise Sibit::NotSupportedError, 'Not implemented yet'
  end

  # This method should fetch a Blockchain block and return as a hash. Raises
  # an exception if the block is not found.
  def block(hash)
    head = Sibit::Json.new(http: @http, log: @log).get(
      Iri.new('https://api-r.bitcoinchain.com/v1/block').append(hash)
    )[0]
    raise Sibit::Error, "The block #{hash} is not found" if head.nil?
    txs = Sibit::Json.new(http: @http, log: @log).get(
      Iri.new('https://api-r.bitcoinchain.com/v1/block/txs').append(hash)
    )
    nxt = head['next_block']
    nxt = nil if nxt == '0000000000000000000000000000000000000000000000000000000000000000'
    {
      provider: self.class.name,
      hash: head['hash'],
      orphan: !head['is_main'],
      next: nxt,
      previous: head['prev_block'],
      txns: txs[0]['txs'].map do |t|
        {
          hash: t['self_hash'],
          outputs: t['outputs'].map do |o|
            {
              address: o['receiver'],
              value: o['value'] * 100_000_000
            }
          end
        }
      end
    }
  end
end
