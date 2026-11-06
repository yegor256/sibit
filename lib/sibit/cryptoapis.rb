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

# Cryptoapis.io API, version 2.
#
# Every request needs a key, which goes into the X-API-Key header.
#
# Documentation: https://developers.cryptoapis.io/
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class Sibit::Cryptoapis
  # Constructor.
  def initialize(key, log: Loog::NULL, http: Sibit::Http.new)
    @key = key
    @http = http
    @log = log
  end

  # Current price of BTC in USD (float returned).
  def price(_currency = 'USD')
    raise(Sibit::NotSupportedError, 'Cryptoapis doesn\'t provide BTC price')
  end

  # Get hash of the block after this one, or NIL if it's the last one in Blockchain.
  def next_of(hash)
    nxt = item('blocks', 'hash', hash)['nextBlockHash']
    nxt = nil if nxt.nil? || nxt.empty?
    @log.debug("The block #{hash} is the latest, there is no next block") if nxt.nil?
    @log.debug("The next block of #{hash} is #{nxt}") unless nxt.nil?
    nxt
  end

  # The height of the block.
  def height(hash)
    h = item('blocks', 'hash', hash)['height']
    raise(Sibit::Error, "The block #{hash} found but the height is absent") if h.nil?
    @log.debug("The height of #{hash} is #{h}")
    h
  end

  # Gets the confirmed balance of the address, in satoshi.
  def balance(address)
    amount = item('addresses', address, 'balance').dig('confirmedBalance', 'amount')
    raise(Sibit::Error, "The balance of #{address} is absent at Cryptoapis") if amount.nil?
    b = Sibit::Coins.new(amount).satoshi
    @log.debug("The balance of #{address} is #{b} satoshi")
    b
  end

  # Get recommended fees, in satoshi per byte.
  def fees
    raise(Sibit::NotSupportedError, 'Cryptoapis doesn\'t provide recommended fees')
  end

  # Gets the hash of the latest block.
  def latest
    hash = item('blocks', 'last')['hash']
    raise(Sibit::Error, 'The latest block hash is absent at Cryptoapis') if hash.nil?
    @log.debug("The latest block hash is #{hash}")
    hash
  end

  # Fetch all unspent outputs per address.
  def utxos(_sources)
    raise(Sibit::NotSupportedError, 'Not implemented yet')
  end

  # Push this transaction (in hex format) to the network.
  def push(hex)
    Sibit::Json.new(http: @http, log: @log).post(
      Iri.new('https://rest.cryptoapis.io/blockchain-tools/bitcoin/mainnet/transactions/broadcast'),
      JSON.generate(data: { item: { signedTransactionHex: hex } }),
      headers: headers.merge('Content-Type' => 'application/json')
    )
    @log.debug("Transaction (#{hex.length} in hex) has been pushed to Cryptoapis")
  end

  # This method should fetch a Blockchain block and return as a hash.
  def block(hash)
    head = item('blocks', 'hash', hash)
    nxt = head['nextBlockHash']
    {
      provider: self.class.name,
      hash: head['hash'],
      orphan: false,
      next: nxt.nil? || nxt.empty? ? nil : nxt,
      previous: head['previousBlockHash'],
      txns: txns(hash)
    }
  end

  private

  def headers
    return {} if @key.nil? || @key.empty?
    { 'X-API-Key' => @key }
  end

  def uri(*path)
    path.reduce(Iri.new('https://rest.cryptoapis.io/blockchain-data/bitcoin/mainnet')) { |u, p| u.append(p) }
  end

  def item(*path)
    i = Sibit::Json.new(http: @http, log: @log)
      .get(uri(*path), headers: headers).dig('data', 'item')
    raise(Sibit::Error, "Cryptoapis returned no item at #{uri(*path)}") if i.nil?
    i
  end

  def txns(hash)
    all = []
    loop do
      items = Sibit::Json.new(http: @http, log: @log).get(
        uri('blocks', 'hash', hash, 'transactions').add(limit: 50, offset: all.length),
        headers: headers
      ).dig('data', 'items')
      raise(Sibit::Error, "No transactions of #{hash} at offset #{all.length}") if items.nil?
      all +=
        items.map do |t|
          {
            hash: t['transactionId'],
            outputs: t['blockchainSpecific']['vout'].map do |o|
              { address: o['scriptPubKey']['addresses'][0], value: Sibit::Coins.new(o['value']).satoshi }
            end
          }
        end
      break if items.length < 50
    end
    all
  end
end
