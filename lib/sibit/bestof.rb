# frozen_string_literal: true

# Copyright (c) 2019-2023 Yegor Bugayenko
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

require 'backtrace'
require_relative 'error'
require_relative 'log'

# API best of.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2023 Yegor Bugayenko
# License:: MIT
class Sibit
  # Best of API.
  class BestOf
    # Constructor.
    def initialize(list, log: Sibit::Log.new, verbose: false)
      @list = list
      @log = log
      @verbose = verbose
    end

    # Current price of BTC in USD (float returned).
    def price(currency = 'USD')
      best_of('price') do |api|
        api.price(currency)
      end
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

    # Push this transaction (in hex format) to the network.
    def push(hex)
      best_of('push') do |api|
        api.push(hex)
      end
    end

    # This method should fetch a block and return as a hash.
    def block(hash)
      best_of('block') do |api|
        api.block(hash)
      end
    end

    private

    def best_of(method)
      return yield @list unless @list.is_a?(Array)
      results = []
      errors = []
      @list.each do |api|
        results << yield(api)
      rescue Sibit::NotSupportedError
        # Just ignore it
      rescue Sibit::Error => e
        errors << e
        @log.info("The API #{api.class.name} failed at #{method}(): #{e.message}") if @verbose
      end
      if results.empty?
        errors.each { |e| @log.info(Backtrace.new(e).to_s) }
        raise Sibit::Error, "No APIs out of #{@list.length} managed to succeed at #{method}(): \
#{@list.map { |a| a.class.name }.join(', ')}"
      end
      results.group_by(&:to_s).values.max_by(&:size)[0]
    end
  end
end
