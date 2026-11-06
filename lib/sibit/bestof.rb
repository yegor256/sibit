# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'backtrace'
require 'loog'
require_relative 'error'

# API best of.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class Sibit::BestOf
  # Constructor.
  def initialize(list, log: Loog::NULL, verbose: false)
    @list = list
    @log = log
    @verbose = verbose
  end

  # Current price of BTC in USD (float returned). Exchanges never quote
  # the exact same number, so this one does not vote: it averages all
  # answers and fails when they are more than five percent apart.
  def price(currency = 'USD')
    return @list.price(currency) unless @list.is_a?(Array)
    average('price', answers('price') { |api| api.price(currency) })
  end

  # Gets the balance of the address, in satoshi.
  def balance(address)
    best_of('balance') do |api|
      api.balance(address)
    end
  end

  # Get the height of the block.
  def height(hash)
    best_of('height') do |api|
      api.height(hash)
    end
  end

  # Get the hash of the next block.
  def next_of(hash)
    best_of('next_of') do |api|
      api.next_of(hash)
    end
  end

  # Get recommended fees, in satoshi per byte. The method returns
  # a hash: { S: 12, M: 45, L: 100, XL: 200 }
  def fees
    best_of('fees', &:fees)
  end

  # Fetch all unspent outputs per address.
  def utxos(keys)
    best_of('utxos') do |api|
      api.utxos(keys)
    end
  end

  # Latest block hash.
  def latest
    best_of('latest', &:latest)
  end

  # Push this transaction (in hex format) to the network. This one does
  # not vote: pushing is a side effect, so it hands the transaction to
  # each API in turn and stops at the first that accepts it.
  def push(hex)
    return @list.push(hex) unless @list.is_a?(Array)
    errors = []
    @list.each do |api|
      return api.push(hex)
    rescue Sibit::NotSupportedError
      nil
    rescue Sibit::Error => e
      errors << e
      @log.debug("The API #{api.class.name} failed at push(): #{e.message}") if @verbose
    end
    errors.each { |e| @log.debug(Backtrace.new(e).to_s) }
    raise(
      Sibit::Error,
      "No APIs out of #{@list.length} managed to succeed at push(): " \
      "#{@list.map { |a| a.class.name }.join(', ')}"
    )
  end

  # This method should fetch a block and return as a hash.
  def block(hash)
    best_of('block') do |api|
      api.block(hash)
    end
  end

  private

  def best_of(method, &blk)
    return yield(@list) unless @list.is_a?(Array)
    majority(method, answers(method, &blk))
  end

  def answers(method)
    votes = []
    errors = []
    @list.each do |api|
      votes << [api.class.name, yield(api)]
    rescue Sibit::NotSupportedError
      nil
    rescue Sibit::Error => e
      errors << e
      @log.debug("The API #{api.class.name} failed at #{method}(): #{e.message}") if @verbose
    end
    if votes.empty?
      errors.each { |e| @log.debug(Backtrace.new(e).to_s) }
      raise(
        Sibit::Error,
        "No APIs out of #{@list.length} managed to succeed at #{method}(): " \
        "#{@list.map { |a| a.class.name }.join(', ')}"
      )
    end
    votes
  end

  def average(method, votes)
    prices = votes.map { |v| v[1] }
    if (prices.max - prices.min) / prices.min > 0.05
      raise(
        Sibit::Error,
        "The answers at #{method}() are more than 5% apart: " \
        "#{votes.map { |name, answer| "#{name}=#{answer}" }.join(', ')}"
      )
    end
    prices.sum / prices.size
  end

  def majority(method, votes)
    winner = votes.group_by { |v| v[1].to_s }.values.max_by(&:size)
    if winner.size <= votes.size / 2
      raise(
        Sibit::Error,
        "No strict majority among #{votes.size} answers at #{method}(): " \
        "#{votes.map { |name, answer| "#{name}=#{answer}" }.join(', ')}"
      )
    end
    winner[0][1]
  end
end
