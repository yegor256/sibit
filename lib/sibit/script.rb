# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'digest'
require_relative 'base58'
require_relative 'bech32'

# Sibit main class.
class Sibit
  # Bitcoin Script parser.
  #
  # Parses standard P2PKH and P2WPKH scripts to extract addresses.
  #
  # Author:: Yegor Bugayenko (yegor256@gmail.com)
  # Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
  # License:: MIT
  class Script
    OP_0 = 0x00
    OP_DUP = 0x76
    OP_HASH160 = 0xa9
    OP_EQUALVERIFY = 0x88
    OP_CHECKSIG = 0xac

    def initialize(hex)
      @bytes = [hex].pack('H*').bytes
    end

    def address(network = :mainnet)
      return p2wpkh_address(network) if p2wpkh?
      return p2pkh_address(network) if p2pkh?
      nil
    end

    def p2pkh?
      @bytes.length == 25 &&
        @bytes[0] == OP_DUP &&
        @bytes[1] == OP_HASH160 &&
        @bytes[2] == 20 &&
        @bytes[23] == OP_EQUALVERIFY &&
        @bytes[24] == OP_CHECKSIG
    end

    def p2wpkh?
      @bytes.length == 22 &&
        @bytes[0] == OP_0 &&
        @bytes[1] == 20
    end

    def hash160
      return @bytes[2, 20].pack('C*').unpack1('H*') if p2wpkh?
      return @bytes[3, 20].pack('C*').unpack1('H*') if p2pkh?
      nil
    end

    private

    def p2pkh_address(network)
      h = hash160
      return nil unless h
      prefix = network == :mainnet ? '00' : '6f'
      versioned = "#{prefix}#{h}"
      checksum = Base58.new(versioned).check
      Base58.new(versioned + checksum).encode
    end

    def p2wpkh_address(network)
      h = hash160
      return nil unless h
      hrp = { mainnet: 'bc', testnet: 'tb', regtest: 'bcrt' }[network]
      Bech32.encode(hrp, 0, h)
    end
  end
end
