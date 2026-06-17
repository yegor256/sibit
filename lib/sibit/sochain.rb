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

# SoChain API (formerly known as Block.io).
#
# Documentation: https://sochain.com/api
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class Sibit::Sochain
  # Constructor.
  def initialize(log: Loog::NULL, http: Sibit::Http.new, network: 'BTC')
    @http = http
    @log = log
    @network = network
  end

  # Current price of BTC in USD (float returned).
  def price(currency = 'USD')
    data = Sibit::Json.new(http: @http, log: @log).get(
      Iri.new('https://sochain.com/api/v2/get_price').append(@network).append(currency)
    )['data']
    raise(Sibit::Error, "No price data returned for #{@network}/#{currency}") if data.nil?
    prices = data['prices']
    if prices.nil? || prices.empty?
      raise(Sibit::Error, "No price quotes for #{@network}/#{currency}")
    end
    price = Float(prices[0]['price'])
    @log.debug("The price of #{@network} is #{price} #{currency}")
    price
  end

  # The height of the block, identified by hash.
  def height(hash)
    data = Sibit::Json.new(http: @http, log: @log).get(
      Iri.new('https://sochain.com/api/v2/block').append(@network).append(hash)
    )['data']
    raise(Sibit::Error, "The block #{hash} not found") if data.nil?
    h = data['block_no']
    raise(Sibit::Error, "The block #{hash} found but the height is absent") if h.nil?
    @log.debug("The height of #{hash} is #{h}")
    Integer(h)
  end

  # Get hash of the block after this one.
  def next_of(hash)
    data = Sibit::Json.new(http: @http, log: @log).get(
      Iri.new('https://sochain.com/api/v2/block').append(@network).append(hash)
    )['data']
    raise(Sibit::Error, "The block #{hash} not found") if data.nil?
    nxt = data['next_blockhash']
    nxt = nil if nxt == '0000000000000000000000000000000000000000000000000000000000000000'
    @log.debug("In SoChain the block #{hash} is the latest, there is no next block") if nxt.nil?
    @log.debug("The next block of #{hash} is #{nxt}") unless nxt.nil?
    nxt
  end

  # Gets the balance of the address, in satoshi.
  def balance(address)
    data = Sibit::Json.new(http: @http, log: @log).get(
      Iri.new('https://sochain.com/api/v2/get_address_balance').append(@network).append(address)
    )['data']
    if data.nil?
      @log.debug("The balance of #{address} is probably zero (not found)")
      return 0
    end
    confirmed = data['confirmed_balance']
    if confirmed.nil?
      @log.debug("The balance of #{address} is probably zero (no confirmed_balance)")
      return 0
    end
    b = Integer((Float(confirmed) * 100_000_000).round)
    @log.debug("The balance of #{address} is #{b} satoshi")
    b
  end

  # Get recommended fees, in satoshi per byte.
  def fees
    raise(Sibit::NotSupportedError, 'SoChain doesn\'t provide recommended fees')
  end

  # Gets the hash of the latest block.
  def latest
    data = Sibit::Json.new(http: @http, log: @log).get(
      Iri.new('https://sochain.com/api/v2/get_info').append(@network)
    )['data']
    raise(Sibit::Error, 'The latest block info not found') if data.nil?
    hash = data['blockhash']
    raise(Sibit::Error, 'The latest block hash is absent') if hash.nil?
    @log.debug("The latest block hash is #{hash}")
    hash
  end

  # Fetch all unspent outputs per address. The argument is an array
  # of Bitcoin addresses.
  def utxos(sources)
    out = []
    sources.each do |address|
      data = Sibit::Json.new(http: @http, log: @log).get(
        Iri.new('https://sochain.com/api/v2/get_tx_unspent').append(@network).append(address)
      )['data']
      next if data.nil?
      txs = data['txs']
      next if txs.nil?
      txs.each do |u|
        out << {
          value: Integer((Float(u['value']) * 100_000_000).round),
          hash: u['txid'],
          index: u['output_no'],
          confirmations: u['confirmations'],
          script: [u['script_hex']].pack('H*')
        }
      end
    end
    out
  end

  # Push this transaction (in hex format) to the network. SoChain expects a
  # JSON payload with the +tx_hex+ field on POST /send_tx/{network}.
  def push(hex)
    uri = URI(Iri.new('https://sochain.com/api/v2/send_tx').append(@network).to_s)
    res = @http.client(uri).post(
      uri.path,
      JSON.generate(tx_hex: hex),
      {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'Accept-Charset' => 'UTF-8',
        'Accept-Encoding' => ''
      }
    )
    unless res.code == '200'
      raise(Sibit::Error, "Failed to push transaction to #{uri}: #{res.code}\n#{res.body}")
    end
    @log.debug("Transaction (#{hex.length} chars in hex) has been pushed to SoChain")
  end

  # This method should fetch a block and return it as a hash.
  def block(hash)
    data = Sibit::Json.new(http: @http, log: @log).get(
      Iri.new('https://sochain.com/api/v2/block').append(@network).append(hash)
    )['data']
    raise(Sibit::Error, "The block #{hash} not found") if data.nil?
    nxt = data['next_blockhash']
    nxt = nil if nxt == '0000000000000000000000000000000000000000000000000000000000000000'
    {
      provider: self.class.name,
      hash: data['blockhash'],
      orphan: data['is_orphan'] == true,
      next: nxt,
      previous: data['previous_blockhash'],
      txns: (data['txs'] || []).map do |t|
        {
          hash: t['txid'] || t,
          outputs: ((t.is_a?(Hash) ? t['outputs'] : nil) || []).map do |o|
            {
              address: o['address'],
              value: Integer((Float(o['value']) * 100_000_000).round)
            }
          end
        }
      end
    }
  end
end
