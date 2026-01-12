# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'ellipsized'
require 'retriable_proxy'
require 'thor'

# Sibit main class.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
# License:: MIT
class Sibit
  # Command-line interface for Sibit.
  #
  # Provides commands to interact with the Bitcoin network.
  #
  # Example:
  #   Sibit::Bin.start(['price'])
  #   Sibit::Bin.start(['balance', '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa'])
  class Bin < Thor
    stop_on_unknown_option!

    class_option :proxy, type: :string, desc: 'HTTPS proxy for all requests, e.g. "localhost:3128"'
    class_option :attempts, type: :numeric, default: 1,
      desc: 'How many times should we try before failing'
    class_option :dry, type: :boolean, default: false,
      desc: "Don't send a real payment, run in a read-only mode"
    class_option :verbose, type: :boolean, default: false, desc: 'Print all possible debug messages'
    class_option :quiet, type: :boolean, default: false, desc: 'Print only informative messages'
    class_option :api, type: :array, default: %w[blockchain btc bitcoinchain blockchair cex],
      desc: 'Ordered List of APIs to use, e.g. "blockchain,btc,bitcoinchain"'
    class_option :base58, type: :boolean, default: false,
      desc: 'Use base58 address format instead of bech32'

    def self.exit_on_failure?
      true
    end

    def self.handle_argument_error(command, error, args, _arity)
      return new.help(command.name) if args.include?('--help') || args.include?('-h')
      unknown = args.find { |a| a.start_with?('-') }
      if unknown
        warn "Unknown option: #{unknown}"
        exit 1
      end
      raise error
    end

    desc 'price', 'Get current price of BTC in USD'
    def price
      log.info(client.price)
    end

    desc 'fees', 'Get currently recommended transaction fees'
    def fees
      sibit = client
      fees = sibit.fees
      text = %i[S M L XL].map do |m|
        sat = fees[m] * 250
        usd = sat * sibit.price / 100_000_000
        "#{m}: #{sat}sat / $#{format('%<usd>.02f', usd: usd)}"
      end.join("\n")
      log.info(text)
    end

    desc 'latest', 'Get hash of the latest block'
    def latest
      log.info(client.latest)
    end

    desc 'generate', 'Generate a new private key'
    def generate
      log.info(client.generate)
    end

    desc 'create KEY', 'Create a public Bitcoin address from the private key'
    def create(key)
      log.debug("Private key provided: #{key.ellipsized(8).inspect}")
      k = Sibit::Key.new(key)
      log.info(options[:base58] ? k.base58 : k.bech32)
    end

    desc 'balance ADDRESS', 'Check the balance of the Bitcoin address'
    def balance(address)
      log.info(client.balance(address))
    end

    desc \
      'pay AMOUNT FEE SOURCES TARGET CHANGE',
      'Send a new Bitcoin transaction (AMOUNT can be "MAX" to use full balance)'
    option :skip_utxo, type: :array, default: [],
      desc: 'List of UTXO that must be skipped while paying'
    option :yes, type: :boolean, default: false,
      desc: 'Skip confirmation prompt and send the payment immediately'
    def pay(amount, fee, sources, target, change)
      keys = sources.split(',')
      if amount.upcase == 'MAX'
        addrs = keys.map do |k|
          kk = Sibit::Key.new(k)
          options[:base58] ? kk.base58 : kk.bech32
        end
        amount = addrs.sum { |a| client.balance(a) }
      end
      amount = amount.to_i if amount.is_a?(String) && /^[0-9]+$/.match?(amount)
      fee = fee.to_i if /^[0-9]+$/.match?(fee)
      args = [amount, fee, keys, target, change]
      kwargs = { skip_utxo: options[:skip_utxo], base58: options[:base58] }
      unless options[:yes] || options[:dry]
        client(dry: true).pay(*args, **kwargs)
        print 'Do you confirm this payment? (yes/no): '
        answer = $stdin.gets&.strip&.downcase
        raise Sibit::Error, 'Payment cancelled by user' unless answer == 'yes'
      end
      log.info(client.pay(*args, **kwargs))
    end

    desc 'version', 'Print program version'
    def version
      log.info(Sibit::VERSION)
    end

    private

    def log
      @log ||= begin
        verbose = !options[:quiet] &&
                  (options[:verbose] || ENV.fetch('SIBIT_VERBOSE', nil))
        verbose ? Loog::VERBOSE : Loog::REGULAR
      end
    end

    def client(dry: false)
      proxy = options[:proxy] || ENV.fetch('SIBIT_PROXY', nil)
      http = proxy ? Sibit::HttpProxy.new(proxy) : Sibit::Http.new
      log.debug("Using proxy at #{http.host}") if proxy
      apis = options[:api].flat_map { |a| a.split(',') }.map(&:downcase).map do |a|
        case a
        when 'blockchain'
          Sibit::Blockchain.new(http: http, log: log)
        when 'btc'
          Sibit::Btc.new(http: http, log: log)
        when 'bitcoinchain'
          Sibit::Bitcoinchain.new(http: http, log: log)
        when 'blockchair'
          Sibit::Blockchair.new(http: http, log: log)
        when 'cex'
          Sibit::Cex.new(http: http, log: log)
        when 'fake'
          Sibit::Fake.new
        else
          raise Sibit::Error, "Unknown API \"#{a}\""
        end
      end
      api = Sibit::FirstOf.new(apis, log: log, verbose: true)
      api = Sibit::Dry.new(api, log: log) if options[:dry] || dry
      api = RetriableProxy.for_object(api, on: Sibit::Error) if options[:attempts] > 1
      Sibit.new(log: log, api: api)
    end
  end
end
