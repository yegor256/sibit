# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'digest'

# Bitcoin primitives module.
#
# Pure Ruby implementation of Bitcoin functionality using OpenSSL 3.0+.
# Replaces the bitcoin-ruby dependency which is incompatible with OpenSSL 3.0.
module Sibit::Bitcoin
  MIN_TX_FEE = 10_000

  # Base58 encoding for Bitcoin addresses.
  #
  # Author:: Yegor Bugayenko (yegor256@gmail.com)
  # Copyright:: Copyright (c) 2019-2025 Yegor Bugayenko
  # License:: MIT
  module Base58
    ALPHABET = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'

    def self.encode(hex)
      bytes = [hex].pack('H*')
      leading = bytes.match(/^\x00*/)[0].length
      num = hex.to_i(16)
      result = ''
      while num.positive?
        num, remainder = num.divmod(58)
        result = ALPHABET[remainder] + result
      end
      ('1' * leading) + result
    end

    def self.decode(str)
      leading = str.match(/^1*/)[0].length
      num = 0
      str.each_char { |c| num = (num * 58) + ALPHABET.index(c) }
      hex = num.zero? ? '' : num.to_s(16)
      hex = "0#{hex}" if hex.length.odd?
      ('00' * leading) + hex
    end

    def self.check(hex)
      Digest::SHA256.hexdigest(Digest::SHA256.digest([hex].pack('H*')))[0...8]
    end
  end
end
