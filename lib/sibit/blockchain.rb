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

require 'bitcoin'
require 'json'
require 'uri'
require_relative 'version'
require_relative 'error'
require_relative 'http'
require_relative 'json'

# Blockchain.info API.
#
# It works through the Blockchain API:
# https://www.blockchain.com/api/blockchain_api
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2020 Yegor Bugayenko
# License:: MIT
class Sibit
  # Blockchain.info API.
  class Blockchain
    # Constructor.
    def initialize(log: Sibit::Log.new, http: Sibit::Http.new, dry: false)
      @http = http
      @log = log
      @dry = dry
    end

    # Current price of BTC in USD (float returned).
    def price(currency)
      h = Sibit::Json.new(http: @http, log: @log).get(
        URI('https://blockchain.info/ticker')
      )[currency]
      raise Error, "Unrecognized currency #{currency}" if h.nil?
      price = h['15m']
      @log.info("The price of BTC is #{price} USD")
      price
    end

    # Gets the balance of the address, in satoshi.
    def balance(address)
      json = Sibit::Json.new(http: @http, log: @log).get(
        URI("https://blockchain.info/rawaddr/#{address}")
      )
      @log.info("Total transactions: #{json['n_tx']}")
      @log.info("Received/sent: #{json['total_received']}/#{json['total_sent']}")
      json['final_balance']
    end

    # Get recommended fees, in satoshi per byte. The method returns
    # a hash: { S: 12, M: 45, L: 100, XL: 200 }
    def fees
      json = Sibit::Json.new(http: @http, log: @log).get(
        URI('https://bitcoinfees.earn.com/api/v1/fees/recommended')
      )
      @log.info("Current recommended Bitcoin fees: \
  #{json['hourFee']}/#{json['halfHourFee']}/#{json['fastestFee']} sat/byte")
      {
        S: json['hourFee'] / 3,
        M: json['hourFee'],
        L: json['halfHourFee'],
        XL: json['fastestFee']
      }
    end

    # Sends a payment and returns the transaction hash.
    def pay(amount, fee, sources, target, change)
      p = price('USD')
      satoshi = satoshi(amount)
      f = mfee(fee, size_of(amount, sources))
      satoshi += f if f.negative?
      raise Error, "The fee #{f.abs} covers the entire amount" if satoshi.zero?
      raise Error, "The fee #{f.abs} is bigger than the amount #{satoshi}" if satoshi.negative?
      builder = Bitcoin::Builder::TxBuilder.new
      unspent = 0
      size = 100
      utxos = Sibit::Json.new(http: @http, log: @log).get(
        URI("https://blockchain.info/unspent?active=#{sources.keys.join('|')}&limit=1000")
      )['unspent_outputs']
      @log.info("#{utxos.count} UTXOs found, these will be used \
  (value/confirmations at tx_hash):")
      utxos.each do |utxo|
        unspent += utxo['value']
        builder.input do |i|
          i.prev_out(utxo['tx_hash_big_endian'])
          i.prev_out_index(utxo['tx_output_n'])
          i.prev_out_script = [utxo['script']].pack('H*')
          address = Bitcoin::Script.new([utxo['script']].pack('H*')).get_address
          i.signature_key(key(sources[address]))
        end
        size += 180
        @log.info(
          "  #{num(utxo['value'], p)}/#{utxo['confirmations']} at #{utxo['tx_hash_big_endian']}"
        )
        break if unspent > satoshi
      end
      if unspent < satoshi
        raise Error, "Not enough funds to send #{num(satoshi, p)}, only #{num(unspent, p)} left"
      end
      builder.output(satoshi, target)
      f = mfee(fee, size)
      tx = builder.tx(
        input_value: unspent,
        leave_fee: true,
        extra_fee: [f, Bitcoin.network[:min_tx_fee]].max,
        change_address: change
      )
      left = unspent - tx.outputs.map(&:value).inject(&:+)
      @log.info("A new Bitcoin transaction #{tx.hash} prepared:
    #{tx.in.count} input#{tx.in.count > 1 ? 's' : ''}:
      #{tx.inputs.map { |i| " in: #{i.prev_out.bth}:#{i.prev_out_index}" }.join("\n    ")}
    #{tx.out.count} output#{tx.out.count > 1 ? 's' : ''}:
      #{tx.outputs.map { |o| "out: #{o.script.bth} / #{num(o.value, p)}" }.join("\n    ")}
    Min tx fee: #{num(Bitcoin.network[:min_tx_fee], p)}
    Fee requested: #{num(f, p)} as \"#{fee}\"
    Fee actually paid: #{num(left, p)}
    Tx size: #{size} bytes
    Unspent: #{num(unspent, p)}
    Amount: #{num(satoshi, p)}
    Target address: #{target}
    Change address is #{change}")
      unless @dry
        Sibit::Json.new(http: @http, log: @log).post(
          URI('https://blockchain.info/pushtx'),
          tx.to_payload.bth
        )
      end
      tx.hash
    end

    # Gets the hash of the latest block.
    def latest
      Sibit::Json.new(http: @http, log: @log).get(
        URI('https://blockchain.info/latestblock')
      )['hash']
    end

    # This method should fetch a Blockchain block and return as a hash.
    def block(_hash)
      raise Sibit::Error, 'Not implemented yet'
    end

    private

    def num(satoshi, usd)
      format(
        '%<satoshi>ss/$%<dollars>0.2f',
        satoshi: satoshi.to_s.gsub(/\d(?=(...)+$)/, '\0,'),
        dollars: satoshi * usd / 100_000_000
      )
    end

    # Convert text to amount.
    def satoshi(amount)
      return amount if amount.is_a?(Integer)
      raise Error, 'Amount should either be a String or Integer' unless amount.is_a?(String)
      return (amount.gsub(/BTC$/, '').to_f * 100_000_000).to_i if amount.end_with?('BTC')
      raise Error, "Can't understand the amount #{amount.inspect}"
    end

    # Calculates a fee in satoshi for the transaction of the specified size.
    # The +fee+ argument could be a number in satoshi, in which case it will
    # be returned as is, or a string like "XL" or "S", in which case the
    # fee will be calculated using the +size+ argument (which is the size
    # of the transaction in bytes).
    def mfee(fee, size)
      return fee.to_i if fee.is_a?(Integer)
      raise Error, 'Fee should either be a String or Integer' unless fee.is_a?(String)
      mul = 1
      if fee.start_with?('+', '-')
        mul = -1 if fee.start_with?('-')
        fee = fee[1..-1]
      end
      sat = fees[fee.to_sym]
      raise Error, "Can't understand the fee: #{fee.inspect}" if sat.nil?
      mul * sat * size
    end

    # Make key from private key string in Hash160.
    def key(hash160)
      key = Bitcoin::Key.new
      key.priv = hash160
      key
    end

    # Calculate an approximate size of the transaction.
    def size_of(amount, sources)
      satoshi = satoshi(amount)
      builder = Bitcoin::Builder::TxBuilder.new
      unspent = 0
      size = 100
      utxos = Sibit::Json.new(http: @http, log: @log).get(
        URI("https://blockchain.info/unspent?active=#{sources.keys.join('|')}&limit=1000")
      )['unspent_outputs']
      utxos.each do |utxo|
        unspent += utxo['value']
        builder.input do |i|
          i.prev_out(utxo['tx_hash_big_endian'])
          i.prev_out_index(utxo['tx_output_n'])
          i.prev_out_script = [utxo['script']].pack('H*')
          address = Bitcoin::Script.new([utxo['script']].pack('H*')).get_address
          i.signature_key(key(sources[address]))
        end
        size += 180
        break if unspent > satoshi
      end
      size
    end
  end
end
