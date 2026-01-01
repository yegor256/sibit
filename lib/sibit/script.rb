# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'digest'
require_relative 'base58'

# Sibit main class.
class Sibit
  # Bitcoin Script parser.
  #
  # Parses standard P2PKH scripts to extract addresses.
  #
  # Author:: Yegor Bugayenko (yegor256@gmail.com)
  # Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
  # License:: MIT
  class Script
    OP_DUP = 0x76
    OP_HASH160 = 0xa9
    OP_EQUALVERIFY = 0x88
    OP_CHECKSIG = 0xac

    def initialize(hex)
      @bytes = [hex].pack('H*').bytes
    end

    def address(network = :mainnet)
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

    def hash160
      return nil unless p2pkh?
      @bytes[3, 20].pack('C*').unpack1('H*')
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
  end
end
