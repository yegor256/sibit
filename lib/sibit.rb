# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'loog'
require_relative 'sibit/bitcoin/base58'
require_relative 'sibit/bitcoin/key'
require_relative 'sibit/bitcoin/script'
require_relative 'sibit/bitcoin/tx'
require_relative 'sibit/bitcoin/txbuilder'
require_relative 'sibit/blockchain'
require_relative 'sibit/version'

# Sibit main class.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
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
  # one of them succeeds.
  def initialize(log: Loog::NULL, api: Sibit::Blockchain.new(log: log))
    @log = log
    @api = api
  end

  # Current price of 1 BTC in USD (or another currency), float returned.
  def price(currency = 'USD')
    raise Error, "Invalid currency #{currency.inspect}" unless /^[A-Z]{3}$/.match?(currency)
    @api.price(currency)
  end

  # Generates new Bitcoin private key and returns in Hash160 format.
  def generate
    key = Key.generate.priv
    @log.info("Bitcoin private key generated: #{key[0..8]}...")
    key
  end

  # Creates Bitcoin address using the private key in Hash160 format.
  def create(pvt)
    Key.new(pvt).addr
  end

  # Gets the balance of the address, in satoshi.
  def balance(address)
    raise Error, "Invalid address #{address.inspect}" unless /^[0-9a-zA-Z]+$/.match?(address)
    @api.balance(address)
  end

  # Get the height of the block.
  def height(hash)
    raise Error, "Invalid block hash #{hash.inspect}" unless /^[0-9a-f]{64}$/.match?(hash)
    @api.height(hash)
  end

  # Get the hash of the next block.
  def next_of(hash)
    raise Error, "Invalid block hash #{hash.inspect}" unless /^[0-9a-f]{64}$/.match?(hash)
    @api.next_of(hash)
  end

  # Get recommended fees, in satoshi per byte. The method returns
  # a hash: { S: 12, M: 45, L: 100, XL: 200 }
  def fees
    @api.fees
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
  # +sources+: the list of private bitcoin keys where the coins are now
  # +target+: the target address to send to
  # +change+: the address where the change has to be sent to
  def pay(amount, fee, sources, target, change, skip_utxo: [])
    p = price('USD')
    sources = sources.map { |k| [Key.new(k).addr, k] }.to_h
    satoshi = satoshi(amount)
    builder = TxBuilder.new
    unspent = 0
    size = 100
    utxos = @api.utxos(sources.keys)
    @log.info("#{utxos.count} UTXOs found, these will be used \
(value/confirmations at tx_hash):")
    utxos.each do |utxo|
      if skip_utxo.include?(utxo[:hash])
        @log.info("UTXO skipped: #{utxo[:hash]}")
        next
      end
      unspent += utxo[:value]
      builder.input do |i|
        i.prev_out(utxo[:hash])
        i.prev_out_index(utxo[:index])
        i.prev_out_script = script_hex(utxo[:script])
        address = Script.new(script_hex(utxo[:script])).address
        k = sources[address]
        raise Error, "UTXO arrived to #{address} is incorrect" unless k
        i.signature_key(key(k))
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
      extra_fee: [f, MIN_TX_FEE].max,
      change_address: change
    )
    left = unspent - tx.outputs.sum(&:value)
    @log.info("A new Bitcoin transaction #{tx.hash} prepared:
  #{tx.in.count} input#{'s' if tx.in.count > 1}:
    #{tx.inputs.map { |i| " in: #{i.prev_out.unpack1('H*')}:#{i.prev_out_index}" }.join("\n    ")}
  #{tx.out.count} output#{'s' if tx.out.count > 1}:
    #{tx.outputs.map { |o| "out: #{o.script_hex} / #{num(o.value, p)}" }.join("\n    ")}
  Min tx fee: #{num(MIN_TX_FEE, p)}
  Fee requested: #{num(f, p)} as \"#{fee}\"
  Fee actually paid: #{num(left, p)}
  Tx size: #{size} bytes
  Unspent: #{num(unspent, p)}
  Amount: #{num(satoshi, p)}
  Target address: #{target}
  Change address is #{change}")
    @api.push(tx.to_payload.bth)
    tx.hash
  end

  # Gets the hash of the latest block.
  def latest
    @api.latest
  end

  # You call this method and provide a callback. You provide the hash
  # of the starting block. The method will go through the Blockchain,
  # fetch blocks and find transactions, one by one, passing them to the
  # callback provided. When finished, the method returns the hash of
  # a new block, not scanned yet or NIL if it's the end of Blockchain.
  #
  # The callback will be called with three arguments:
  # 1) Bitcoin address of the receiver, 2) transaction hash, 3) amount
  # in satoshi. The callback should return non-false if the transaction
  # found was useful.
  def scan(start, max: 4)
    raise Error, "Invalid block hash #{start.inspect}" unless /^[0-9a-f]{64}$/.match?(start)
    raise Error, "The max number must be above zero: #{max}" if max < 1
    block = start
    count = 0
    json = {}
    loop do
      json = @api.block(block)
      if json[:orphan]
        steps = 4
        @log.info("Orphan block found at #{block}, moving #{steps} steps back...")
        steps.times do
          block = json[:previous]
          @log.info("Moved back to #{block}")
          json = @api.block(block)
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
      count += 1
      @log.info("We checked #{checked} txns and #{checked_outputs} outputs \
in block #{block} (by #{json[:provider]})")
      block = json[:next]
      begin
        if block.nil?
          @log.info("The next_block is empty in #{json[:hash]}, this may be the end...")
          block = @api.next_of(json[:hash])
        end
      rescue Sibit::Error => e
        @log.info("Failed to get the next_of(#{json[:hash]}), quitting: #{e.message}")
        break
      end
      if block.nil?
        @log.info("The block #{json[:hash]} is definitely the end of Blockchain, we stop.")
        break
      end
      if count >= max
        @log.info("Too many blocks (#{count}) in one go, let's get back to it next time")
        break
      end
    end
    @log.info("Scanned from #{start} to #{json[:hash]} (#{count} blocks)")
    json[:hash]
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
    if fee.end_with?('+', '-')
      mul = -1 if fee.end_with?('-')
      fee = fee[0..-2]
    end
    sat = fees[fee.to_sym]
    raise Error, "Can't understand the fee: #{fee.inspect}" if sat.nil?
    mul * sat * size
  end

  # Make key from private key string in Hash160.
  def key(hash160)
    Key.new(hash160)
  end

  # Convert script to hex string if needed.
  def script_hex(script)
    return script if script.is_a?(String) && script.match?(/\A[0-9a-f]+\z/i)
    script.unpack1('H*')
  end
end
