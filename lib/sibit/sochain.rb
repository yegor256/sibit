# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'iri'
require 'json'
require 'loog'
require 'uri'
require_relative 'coins'
require_relative 'error'
require_relative 'http'
require_relative 'json'
require_relative 'version'

# SoChain API v3 (formerly known as Block.io).
#
# It works without a key, within a daily limit per IP address,
# while a key lifts that limit. API v3 has no way to broadcast a
# transaction and lists only bare transaction hashes in a block.
#
# Documentation: https://sochain.com/api
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class Sibit::Sochain
  # Constructor.
  def initialize(key: nil, log: Loog::NULL, http: Sibit::Http.new, network: 'BTC')
    @key = key
    @http = http
    @log = log
    @network = network
  end

  # Current price of BTC in the currency (float returned).
  def price(currency = 'USD')
    p = data('price', currency: currency)['value']
    raise(Sibit::Error, "No price of #{@network} in #{currency} at SoChain") if p.nil?
    @log.debug("The price of #{@network} is #{p} #{currency}")
    Float(p)
  end

  # The height of the block, identified by hash.
  def height(hash)
    h = data('block', hash)['height']
    raise(Sibit::Error, "The block #{hash} found but the height is absent") if h.nil?
    @log.debug("The height of #{hash} is #{h}")
    Integer(h)
  end

  # Get hash of the block after this one, or NIL if it's the last one in Blockchain.
  def next_of(hash)
    nxt = data('block', hash)['next_block_hash']
    @log.debug("In SoChain the block #{hash} is the latest, there is no next block") if nxt.nil?
    @log.debug("The next block of #{hash} is #{nxt}") unless nxt.nil?
    nxt
  end

  # Gets the confirmed balance of the address, in satoshi.
  def balance(address)
    confirmed = data('balance', address)['confirmed']
    raise(Sibit::Error, "The balance of #{address} is absent at SoChain") if confirmed.nil?
    b = Sibit::Coins.new(confirmed).satoshi
    @log.debug("The balance of #{address} is #{b} satoshi")
    b
  end

  # Get recommended fees, in satoshi per byte.
  def fees
    raise(Sibit::NotSupportedError, 'SoChain doesn\'t provide recommended fees')
  end

  # Gets the hash of the latest block.
  def latest
    hash = data('best_block_hash')['hash']
    raise(Sibit::Error, 'The latest block hash is absent at SoChain') if hash.nil?
    @log.debug("The latest block hash is #{hash}")
    hash
  end

  # Fetch all unspent outputs per address. The argument is an array
  # of Bitcoin addresses.
  def utxos(sources)
    tip = Integer(data('network_info')['block_count'])
    sources.flat_map do |address|
      all = []
      page = 1
      loop do
        outputs = data('unspent_outputs', address, page.to_s)['outputs']
        raise(Sibit::Error, "The unspent outputs of #{address} are absent") if outputs.nil?
        all +=
          outputs.map do |u|
            {
              value: Sibit::Coins.new(u['value']).satoshi,
              hash: u['hash'],
              index: u['index'],
              confirmations: u['block'].nil? ? 0 : tip - u['block'] + 1,
              script: [u['script']].pack('H*')
            }
          end
        break if outputs.length < 10
        page += 1
      end
      all
    end
  end

  # Push this transaction (in hex format) to the network.
  def push(_hex)
    raise(Sibit::NotSupportedError, 'SoChain API v3 doesn\'t broadcast transactions')
  end

  # This method should fetch a block and return it as a hash.
  def block(_hash)
    raise(Sibit::NotSupportedError, 'SoChain API v3 doesn\'t list outputs of block transactions')
  end

  private

  def data(method, *path, **query)
    uri = path.reduce(Iri.new('https://sochain.com/api/v3').append(method).append(@network)) { |u, p| u.append(p) }
    uri = uri.add(**query) unless query.empty?
    d = Sibit::Json.new(http: @http, log: @log).get(
      uri, headers: @key.nil? ? {} : { 'API-KEY' => @key }
    )['data']
    raise(Sibit::Error, "SoChain returned no data at #{uri}") if d.nil?
    d
  end
end
