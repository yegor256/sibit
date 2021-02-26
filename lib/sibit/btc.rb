# frozen_string_literal: true

# Copyright (c) 2019-2021 Yegor Bugayenko
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
require_relative 'log'
require_relative 'version'

# Btc.com API.
#
# Here: https://btc.com/api-doc
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2021 Yegor Bugayenko
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
    def price(_currency = 'USD')
      raise Sibit::NotSupportedError, 'Btc.com API doesn\'t provide prices'
    end

    # Gets the balance of the address, in satoshi.
    def balance(address)
      uri = Iri.new('https://chain.api.btc.com/v3/address').append(address).append('unspent')
      json = Sibit::Json.new(http: @http, log: @log).get(uri)
      if json['err_no'] == 1
        @log.info("The balance of #{address} is zero (not found)")
        return 0
      end
      data = json['data']
      if data.nil?
        @log.info("The balance of #{address} is probably zero (not found)")
        return 0
      end
      txns = data['list']
      if txns.nil?
        @log.info("The balance of #{address} is probably zero (not found)")
        return 0
      end
      balance = txns.map { |tx| tx['value'] }.inject(&:+) || 0
      @log.info("The balance of #{address} is #{balance}, total txns: #{txns.count}")
      balance
    end

    # Get hash of the block after this one.
    def next_of(hash)
      head = Sibit::Json.new(http: @http, log: @log).get(
        Iri.new('https://chain.api.btc.com/v3/block').append(hash)
      )
      data = head['data']
      raise Sibit::Error, "The block #{hash} not found" if data.nil?
      nxt = data['next_block_hash']
      nxt = nil if nxt == '0000000000000000000000000000000000000000000000000000000000000000'
      @log.info("In BTC.com the block #{hash} is the latest, there is no next block") if nxt.nil?
      @log.info("The next block of #{hash} is #{nxt}") unless nxt.nil?
      nxt
    end

    # The height of the block.
    def height(hash)
      json = Sibit::Json.new(http: @http, log: @log).get(
        Iri.new('https://chain.api.btc.com/v3/block').append(hash)
      )
      data = json['data']
      raise Sibit::Error, "The block #{hash} not found" if data.nil?
      h = data['height']
      raise Sibit::Error, "The block #{hash} found but the height is absent" if h.nil?
      @log.info("The height of #{hash} is #{h}")
      h
    end

    # Get recommended fees, in satoshi per byte.
    def fees
      raise Sibit::NotSupportedError, 'Btc.com doesn\'t provide recommended fees'
    end

    # Gets the hash of the latest block.
    def latest
      uri = Iri.new('https://chain.api.btc.com/v3/block/latest')
      json = Sibit::Json.new(http: @http, log: @log).get(uri)
      data = json['data']
      raise Sibit::Error, 'The latest block not found' if data.nil?
      hash = data['hash']
      @log.info("The hash of the latest block is #{hash}")
      hash
    end

    # Fetch all unspent outputs per address.
    def utxos(sources)
      txns = []
      sources.each do |hash|
        json = Sibit::Json.new(http: @http, log: @log).get(
          Iri.new('https://chain.api.btc.com/v3/address').append(hash).append('unspent')
        )
        data = json['data']
        raise Sibit::Error, "The address #{hash} not found" if data.nil?
        txns = data['list']
        next if txns.nil?
        txns.each do |u|
          outs = Sibit::Json.new(http: @http, log: @log).get(
            Iri.new('https://chain.api.btc.com/v3/tx').append(u['tx_hash']).add(verbose: 3)
          )['data']['outputs']
          outs.each_with_index do |o, i|
            next unless o['addresses'].include?(hash)
            txns << {
              value: o['value'],
              hash: u['tx_hash'],
              index: i,
              confirmations: u['confirmations'],
              script: [o['script_hex']].pack('H*')
            }
          end
        end
      end
      txns
    end

    # Push this transaction (in hex format) to the network.
    def push(_hex)
      raise Sibit::NotSupportedError, 'Btc.com doesn\'t provide payment gateway'
    end

    # This method should fetch a Blockchain block and return as a hash.
    def block(hash)
      head = Sibit::Json.new(http: @http, log: @log).get(
        Iri.new('https://chain.api.btc.com/v3/block').append(hash)
      )
      data = head['data']
      raise Sibit::Error, "The block #{hash} not found" if data.nil?
      nxt = data['next_block_hash']
      nxt = nil if nxt == '0000000000000000000000000000000000000000000000000000000000000000'
      {
        provider: self.class.name,
        hash: data['hash'],
        orphan: data['is_orphan'],
        next: nxt,
        previous: data['prev_block_hash'],
        txns: txns(hash)
      }
    end

    private

    def txns(hash)
      page = 1
      psize = 50
      all = []
      loop do
        data = Sibit::Json.new(http: @http, log: @log).get(
          Iri.new('https://chain.api.btc.com/v3/block')
            .append(hash).append('tx').add(page: page, pagesize: psize)
        )['data']
        raise Sibit::Error, "The block #{hash} has no data at page #{page}" if data.nil?
        list = data['list']
        raise Sibit::Error, "The list is empty for block #{hash} at page #{page}" if list.nil?
        txns = list.map do |t|
          {
            hash: t['hash'],
            outputs: t['outputs'].reject { |o| o['spent_by_tx'] }.map do |o|
              {
                address: o['addresses'][0],
                value: o['value']
              }
            end
          }
        end
        all += txns
        page += 1
        break if txns.length < psize
      end
      all
    end
  end
end
