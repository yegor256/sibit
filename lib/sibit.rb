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

require 'bitcoin'
require 'typhoeus'
require 'json'

# Sibit main class.
#
# It works through the Blockchain API at the moment:
# https://www.blockchain.com/api/blockchain_api
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019 Yegor Bugayenko
# License:: MIT
class Sibit
  # Constructor.
  def initialize(log: STDOUT)
    @log = log
  end

  # Generate new Bitcon private key and returns in Hash160 format.
  def generate
    Bitcoin::Key.generate.priv
  end

  # Create Bitcon address using the private key in Hash160 format.
  def create(pvt)
    key(pvt).addr
  end

  # Get the balance of the address, in satoshi.
  def balance(address)
    get_json("https://blockchain.info/rawaddr/#{address}")['final_balance']
  end

  # Send a payment and return the transaction hash.
  #
  # +pvt+: the private key as a Hash160 string
  # +amount+: the amount either in satoshis or ending with 'BTC', like '0.7BTC'
  # +fee+: the miners fee in satoshis (as integer) or S/M/X/XL as a string
  # +sources+: the array of bitcoin addresses where the coins are now
  # +target+: the target address to send to
  # +change+: the address where the change has to be sent to
  def pay(pvt, amount, fee, sources, target, change)
    satoshi = satoshi(amount)
    builder = Bitcoin::Builder::TxBuilder.new
    unspent = 0
    size = 100
    utxos(sources).each do |utxo|
      unspent += utxo['value']
      builder.input do |i|
        i.prev_out(utxo['tx_hash_big_endian'])
        i.prev_out_index(utxo['tx_output_n'])
        i.prev_out_script = [utxo['script']].pack('H*')
        i.signature_key(key(pvt))
      end
      size += 180
      break if unspent > satoshi
    end
    raise "Not enough funds to send #{amount}, only #{unspent} left" if unspent < satoshi
    builder.output(satoshi, target)
    tx = builder.tx(
      input_value: unspent,
      leave_fee: mfee(fee, size),
      change_address: change
    )
    post_tx(tx.to_payload.bth)
    tx.hash
  end

  private

  # Retrieve all unspent outputs of the given list of
  # addresses.
  def utxos(sources)
    offset = 0
    txns = []
    loop do
      uri = [
        'https://blockchain.info/unspent?',
        "active=#{sources.join('|')}",
        offset.positive? ? "&offset=#{offset}" : ''
      ].join
      list = get_json(uri)['unspent_outputs']
      txns += list
      break if list.empty?
      offset += list.count
    end
    txns
  end

  # Convert text to amount.
  def satoshi(amount)
    return (amount.gsub(/BTC$/, '').to_f * 100_000_000).to_i if amount.end_with?('BTC')
    amount.to_i
  end

  def mfee(fee, size)
    return fee.to_i if fee.is_a?(Integer) || /^[0-9]+$/.match?(fee)
    case fee
    when 'S'
      return 10 * size
    when 'M'
      return 50 * size
    when 'L'
      return 100 * size
    when 'XL'
      return 250 * size
    else
      raise "Can't understand the fee: #{fee.inspect}"
    end
  end

  # Make key from private key string in Hash160.
  def key(hash160)
    key = Bitcoin::Key.new
    key.priv = hash160
    key
  end

  def post_tx(body)
    uri = 'https://blockchain.info/pushtx'
    request = Typhoeus::Request.new(uri, method: :post, body: { tx: body })
    request.run
    response = request.response
    raise "Invalid response at #{uri}: #{response.code}" unless response.code == 200
    debug("POST #{uri}: #{response.code}")
  end

  def get_json(uri)
    request = Typhoeus::Request.new(uri, method: :get, headers: {})
    request.run
    response = request.response
    raise "Invalid response at #{uri}: #{response.code}" unless response.code == 200
    debug("GET #{uri}: #{response.code}")
    JSON.parse(response.body)
  end

  def debug(msg)
    if @log.respond_to?(:debug)
      @log.debug(msg)
    elsif @log.respond_to?(:puts)
      @log.puts(msg)
    end
  end
end
