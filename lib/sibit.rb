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

require 'net/http'
require 'uri'
require 'bitcoin'
require 'json'
require 'cgi'
require_relative 'sibit/version'

# Sibit main class.
#
# It works through the Blockchain API at the moment:
# https://www.blockchain.com/api/blockchain_api
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019 Yegor Bugayenko
# License:: MIT
class Sibit
  # If something goes wrong.
  class Error < StandardError; end

  # Fake one, which is useful for testing.
  class Fake
    def price(_cur = 'USD')
      4_000
    end

    def fees
      { S: 12, M: 45, L: 100, XL: 200 }
    end

    def generate
      'fd2333686f49d8647e1ce8d5ef39c304520b08f3c756b67068b30a3db217dcb2'
    end

    def create(_pvt)
      '1JvCsJtLmCxEk7ddZFnVkGXpr9uhxZPmJi'
    end

    def balance(_address)
      100_000_000
    end

    def pay(_amount, _fee, _sources, _target, _change)
      '9dfe55a30b5ee732005158c589179a398117117a68d21531fb6c78b85b544c54'
    end

    def latest
      '00000000000000000008df8a6e1b61d1136803ac9791b8725235c9f780b4ed71'
    end

    def get_json(_uri)
      {}
    end
  end

  # This HTTP client will be used by default.
  def self.default_http
    http = Net::HTTP.new('blockchain.info', 443)
    http.use_ssl = true
    http
  end

  # This HTTP client with proxy.
  def self.proxy_http(addr)
    host, port = addr.split(':')
    http = Net::HTTP.new('blockchain.info', 443, host, port.to_i)
    http.use_ssl = true
    http
  end

  # Constructor.
  #
  # You may provide the log you want to see the messages in. If you don't
  # provide anything, the console will be used. The object you provide
  # has to respond to the method +info+ or +puts+ in order to receive logging
  # messages.
  def initialize(log: STDOUT, http: Sibit.default_http, dry: false, attempts: 1)
    @log = log
    @http = http
    @dry = dry
    @attempts = attempts
  end

  # Current price of 1 BTC.
  def price(cur = 'USD')
    h = get_json('/ticker')[cur.upcase]
    raise Error, "Unrecognized currency #{cur}" if h.nil?
    h['15m']
  end

  # Generates new Bitcon private key and returns in Hash160 format.
  def generate
    key = Bitcoin::Key.generate.priv
    info("Bitcoin private key generated: #{key[0..8]}...")
    key
  end

  # Creates Bitcon address using the private key in Hash160 format.
  def create(pvt)
    key(pvt).addr
  end

  # Gets the balance of the address, in satoshi.
  def balance(address)
    json = get_json("/rawaddr/#{address}")
    info("Total transactions: #{json['n_tx']}")
    info("Received/sent: #{json['total_received']}/#{json['total_sent']}")
    json['final_balance']
  end

  # Get recommended fees, in satoshi per byte. The method returns
  # a hash: { S: 12, M: 45, L: 100, XL: 200 }
  def fees
    json = JSON.parse(
      Net::HTTP.get(
        URI('https://bitcoinfees.earn.com/api/v1/fees/recommended')
      )
    )
    info("Current recommended Bitcoin fees: \
#{json['hourFee']}/#{json['halfHourFee']}/#{json['fastestFee']} sat/byte")
    {
      S: json['hourFee'] / 3,
      M: json['hourFee'],
      L: json['halfHourFee'],
      XL: json['fastestFee']
    }
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
    p = price
    satoshi = satoshi(amount)
    f = mfee(fee, size_of(amount, sources))
    satoshi += f if f.negative?
    raise Error, "The fee #{f.abs} covers the entire amount" if satoshi.zero?
    raise Error, "The fee #{f.abs} is bigger than the amount #{satoshi}" if satoshi.negative?
    builder = Bitcoin::Builder::TxBuilder.new
    unspent = 0
    size = 100
    utxos = get_json(
      "/unspent?active=#{sources.keys.join('|')}&limit=1000"
    )['unspent_outputs']
    info("#{utxos.count} UTXOs found, these will be used \
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
      info("  #{num(utxo['value'], p)}/#{utxo['confirmations']} at #{utxo['tx_hash_big_endian']}")
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
      extra_fee: f.abs - Bitcoin.network[:min_tx_fee],
      change_address: change
    )
    left = unspent - tx.outputs.map(&:value).inject(&:+)
    info("A new Bitcoin transaction #{tx.hash} prepared:
  #{tx.in.count} input#{tx.in.count > 1 ? 's' : ''}:
    #{tx.inputs.map { |i| " in: #{i.prev_out.bth}:#{i.prev_out_index}" }.join("\n    ")}
  #{tx.out.count} output#{tx.out.count > 1 ? 's' : ''}:
    #{tx.outputs.map { |o| "out: #{o.script.bth} / #{num(o.value, p)}" }.join("\n    ")}
  Min tx fee: #{num(Bitcoin.network[:min_tx_fee], p)}
  Fee left: #{num(left, p)}
  Tx size: #{size} bytes
  Unspent: #{num(unspent, p)}
  Amount: #{num(satoshi, p)}
  Target address: #{target}
  Change address is #{change}")
    post_tx(tx.to_payload.bth) unless @dry
    tx.hash
  end

  # Gets the hash of the latest block.
  def latest
    get_json('/latestblock')['hash']
  end

  # Send GET request to the Blockchain API and return JSON response.
  # This method will also log the process and will validate the
  # response for correctness.
  def get_json(uri)
    start = Time.now
    attempt = 0
    begin
      res = @http.get(
        uri,
        'Accept' => 'text/plain',
        'User-Agent' => user_agent,
        'Accept-Encoding' => ''
      )
      raise Error, "Failed to retrieve #{uri} (#{res.code}): #{res.body}" unless res.code == '200'
      info("GET #{uri}: #{res.code}/#{res.body.length}b in #{age(start)}")
      JSON.parse(res.body)
    rescue StandardError => e
      attempt += 1
      raise e if attempt >= @attempts
      retry
    end
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

  def age(start)
    "#{((Time.now - start) * 1000).round}ms"
  end

  def post_tx(body)
    start = Time.now
    attempt = 0
    begin
      uri = '/pushtx'
      res = @http.post(
        '/pushtx',
        "tx=#{CGI.escape(body)}",
        'Accept' => 'text/plain',
        'User-Agent' => user_agent,
        'Accept-Encoding' => '',
        'Content-Type' => 'application/x-www-form-urlencoded'
      )
      raise Error, "Failed to post tx to #{uri}: #{res.code}\n#{res.body}" unless res.code == '200'
      info("POST #{uri}: #{res.code} in #{age(start)}")
    rescue StandardError => e
      attempt += 1
      raise e if attempt >= @attempts
      retry
    end
  end

  # Calculate an approximate size of the transaction.
  def size_of(amount, sources)
    satoshi = satoshi(amount)
    builder = Bitcoin::Builder::TxBuilder.new
    unspent = 0
    size = 100
    utxos = get_json(
      "/unspent?active=#{sources.keys.join('|')}&limit=1000"
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

  def info(msg)
    if @log.respond_to?(:info)
      @log.info(msg)
    elsif @log.respond_to?(:puts)
      @log.puts(msg)
    end
  end

  def user_agent
    "Anonymous/#{Sibit::VERSION}"
  end
end
