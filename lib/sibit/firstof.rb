# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'backtrace'
require 'loog'
require_relative 'error'

# API first of.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class Sibit::FirstOf
  # Constructor.
  def initialize(list, log: Loog::NULL, verbose: false)
    @list = list
    @log = log
    @verbose = verbose
  end

  # Current price of BTC in USD (float returned).
  def price(currency = 'USD')
    first_of('price') do |api|
      api.price(currency)
    end
  end

  # Gets the balance of the address, in satoshi.
  def balance(address)
    first_of('balance') do |api|
      api.balance(address)
    end
  end

  # Get the height of the block.
  def height(hash)
    first_of('height') do |api|
      api.height(hash)
    end
  end

  # Get the hash of the next block.
  def next_of(hash)
    first_of('next_of') do |api|
      api.next_of(hash)
    end
  end

  # Get recommended fees, in satoshi per byte. The method returns
  # a hash: { S: 12, M: 45, L: 100, XL: 200 }
  def fees
    first_of('fees', &:fees)
  end

  # Fetch all unspent outputs per address.
  def utxos(keys)
    first_of('utxos') do |api|
      api.utxos(keys)
    end
  end

  # Latest block hash.
  def latest
    first_of('latest', &:latest)
  end

  # Push this transaction (in hex format) to the network.
  def push(hex)
    first_of('push') do |api|
      api.push(hex)
    end
  end

  # This method should fetch a block and return as a hash.
  def block(hash)
    first_of('block') do |api|
      api.block(hash)
    end
  end

  private

  def first_of(method)
    return yield @list unless @list.is_a?(Array)
    errors = []
    done = false
    result = nil
    @list.each do |api|
      @log.debug("Calling #{api.class.name}##{method}()...")
      begin
        result = yield api
        done = true
        break
      rescue Sibit::NotSupportedError
        # Just ignore it
      rescue Sibit::Error => e
        errors << e
        @log.debug("The API #{api.class.name} failed at #{method}(): #{e.message}") if @verbose
      end
    end
    unless done
      errors.each { |e| @log.debug(Backtrace.new(e).to_s) }
      raise Sibit::Error, "No APIs out of #{@list.length} managed to succeed at #{method}(): \
#{@list.map { |a| a.class.name }.join(', ')}"
    end
    result
  end
end
