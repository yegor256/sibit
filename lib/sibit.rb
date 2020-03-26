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
require_relative 'sibit/version'
require_relative 'sibit/log'
require_relative 'sibit/blockchain'

# Sibit main class.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2020 Yegor Bugayenko
# License:: MIT
class Sibit
  # Constructor.
  #
  # You may provide the log you want to see the messages in. If you don't
  # provide anything, the console will be used. The object you provide
  # has to respond to the method +info+ or +puts+ in order to receive logging
  # messages.
  #
  # It is recommended to wrap the API in a RetriableProxy from
  # retriable_proxy gem and to configure it to retry on Sibit::Error:
  #
  #  RetriableProxy.for_object(api, on: Sibit::Error)
  #
  # This will help you avoid some temporary network issues.
  #
  # The +api+ argument can be an object or an array of objects. If an array
  # is provided, we will make an attempt to try them one by one, until
  # one of them succeedes.
  def initialize(log: STDOUT, api: Sibit::Blockchain.new(log: Sibit::Log.new(log)))
    @log = Sibit::Log.new(log)
    @api = api
  end

  # Current price of 1 BTC in USD (or another currency), float returned.
  def price(currency = 'USD')
    first_one do |api|
      api.price(currency)
    end
  end

  # Generates new Bitcon private key and returns in Hash160 format.
  def generate
    key = Bitcoin::Key.generate.priv
    @log.info("Bitcoin private key generated: #{key[0..8]}...")
    key
  end

  # Creates Bitcon address using the private key in Hash160 format.
  def create(pvt)
    key = Bitcoin::Key.new
    key.priv = pvt
    key.addr
  end

  # Gets the balance of the address, in satoshi.
  def balance(address)
    first_one do |api|
      api.balance(address)
    end
  end

  # Get recommended fees, in satoshi per byte. The method returns
  # a hash: { S: 12, M: 45, L: 100, XL: 200 }
  def fees
    first_one(&:fees)
  end

  # Sends a payment and returns the transaction hash.
  #
  # If the payment can't be signed (the key is wrong, for example) or the
  # previous transaction is not found, or there is a network error, or
  # any other reason, you will get an exception. In this case, just try again.
  # It's safe to try as many times as you need. Don't worry about duplicating
  # your transaction, the Bitcoin network will filter duplicates out.
  #
  # If there are more than 1000 UTXOs in the address where you are trying
  # to send bitcoins from, this method won't be helpful.
  #
  # +amount+: the amount either in satoshis or ending with 'BTC', like '0.7BTC'
  # +fee+: the miners fee in satoshis (as integer) or S/M/X/XL as a string
  # +sources+: the hashmap of bitcoin addresses where the coins are now, with
  # their addresses as keys and private keys as values
  # +target+: the target address to send to
  # +change+: the address where the change has to be sent to
  def pay(amount, fee, sources, target, change)
    p = price('USD')
    satoshi = satoshi(amount)
    builder = Bitcoin::Builder::TxBuilder.new
    unspent = 0
    size = 100
    utxos = first_one { |api| api.utxos(sources.keys) }
    @log.info("#{utxos.count} UTXOs found, these will be used \
(value/confirmations at tx_hash):")
    utxos.each do |utxo|
      unspent += utxo[:value]
      builder.input do |i|
        i.prev_out(utxo[:hash])
        i.prev_out_index(utxo[:index])
        i.prev_out_script = utxo[:script]
        address = Bitcoin::Script.new(utxo[:script]).get_address
        i.signature_key(key(sources[address]))
      end
      size += 180
      @log.info(
        "  #{num(utxo[:value], p)}/#{utxo[:confirmations]} at #{utxo[:hash]}"
      )
      break if unspent > satoshi
    end
    if unspent < satoshi
      raise Error, "Not enough funds to send #{num(satoshi, p)}, only #{num(unspent, p)} left"
    end
    builder.output(satoshi, target)
    f = mfee(fee, size)
    satoshi += f if f.negative?
    raise Error, "The fee #{f.abs} covers the entire amount" if satoshi.zero?
    raise Error, "The fee #{f.abs} is bigger than the amount #{satoshi}" if satoshi.negative?
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
    first_one do |api|
      api.push(tx.to_payload.bth)
    end
    tx.hash
  end

  # Gets the hash of the latest block.
  def latest
    first_one(&:latest)
  end

  # You call this method and provide a callback. You provide the hash
  # of the starting block. The method will go through the Blockchain,
  # fetch blocks and find transactions, one by one, passing them to the
  # callback provided. When finished, the method returns the hash of
  # a new block, seen last.
  #
  # The callback will be called with three arguments:
  # 1) Bitcoin address of the receiver, 2) transaction hash, 3) amount
  # in satoshi. The callback should return non-false if the transaction
  # found was useful.
  def scan(start, max: 4)
    block = start
    count = 0
    wrong = []
    loop do
      json = first_one { |api| api.block(block) }
      if json[:orphan]
        steps = 4
        @log.info("Orphan block found at #{block}, moving #{steps} steps back...")
        wrong << block
        steps.times do
          block = json[:previous]
          wrong << block
          @log.info("Moved back to #{block}")
          json = first_one { |api| api.block(block) }
        end
        next
      end
      checked = 0
      checked_outputs = 0
      json[:txns].each do |t|
        t[:outputs].each_with_index do |o, i|
          address = o[:address]
          checked_outputs += 1
          hash = "#{t[:hash]}:#{i}"
          satoshi = o[:value]
          if yield(address, hash, satoshi)
            @log.info("Bitcoin tx found at #{hash} for #{satoshi} sent to #{address}")
          end
        end
        checked += 1
      end
      @log.info("We checked #{checked} txns and #{checked_outputs} outputs in block #{block}")
      n = json[:next]
      if n.nil?
        @log.info("The next_block is empty in block #{block}, this is the end of Blockchain")
        break
      end
      block = n
      count += 1
      if count > max
        @log.info("Too many blocks (#{count}) in one go, let's get back to it next time")
        break
      end
    end
    block
  end

  private

  def first_one
    return yield @api unless @api.is_a?(Array)
    done = false
    result = nil
    @api.each do |api|
      begin
        result = yield api
        done = true
        break
      rescue Sibit::Error => e
        @log.info("The API #{api.class.name} failed: #{e.message}")
      end
    end
    unless done
      raise Sibit::Error, "No APIs out of #{@api.length} managed to succeed: \
#{@api.map { |a| a.class.name }.join(', ')}"
    end
    result
  end

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
    unless amount.is_a?(String)
      raise Error, "Amount should either be a String or Integer, #{amount.class.name} provided"
    end
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
end
