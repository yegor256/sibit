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
require_relative 'sibit/version'
require_relative 'sibit/log'
require_relative 'sibit/blockchain'

# Sibit main class.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019 Yegor Bugayenko
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
    first_one do |api|
      api.pay(amount, fee, sources, target, change)
    end
  end

  # Gets the hash of the latest block.
  def latest
    first_one(&:latest)
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
    raise Sibit::Error, 'No APIs managed to succeed' unless done
    result
  end
end
