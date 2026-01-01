# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'digest'
require_relative 'error'

# Sibit main class.
class Sibit
  # Base58 encoding for Bitcoin addresses.
  #
  # Encapsulates hex data and provides encoding/decoding functionality.
  #
  # Author:: Yegor Bugayenko (yegor256@gmail.com)
  # Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
  # License:: MIT
  class Base58
    ALPHABET = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'

    def initialize(data)
      @data = data
    end

    def encode
      bytes = [@data].pack('H*')
      leading = bytes.match(/^\x00*/)[0].length
      num = @data.to_i(16)
      result = ''
      while num.positive?
        num, remainder = num.divmod(58)
        result = ALPHABET[remainder] + result
      end
      ('1' * leading) + result
    end

    def decode
      leading = @data.match(/^1*/)[0].length
      num = 0
      @data.each_char do |c|
        idx = ALPHABET.index(c)
        raise Sibit::Error, "Invalid Base58 character '#{c}' in address '#{@data}'" if idx.nil?
        num = (num * 58) + idx
      end
      hex = num.zero? ? '' : num.to_s(16)
      hex = "0#{hex}" if hex.length.odd?
      ('00' * leading) + hex
    end

    def check
      Digest::SHA256.hexdigest(Digest::SHA256.digest([@data].pack('H*')))[0...8]
    end
  end
end
