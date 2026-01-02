# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require_relative 'error'

# Sibit main class.
class Sibit
  # Bech32 encoding and decoding for SegWit addresses.
  #
  # Encodes witness programs to Bech32 addresses (bc1...) and decodes them back.
  #
  # Author:: Yegor Bugayenko (yegor256@gmail.com)
  # Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
  # License:: MIT
  class Bech32
    CHARSET = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l'
    GENERATOR = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3].freeze

    def self.encode(hrp, ver, prog)
      bytes = [prog].pack('H*').bytes
      data = [ver] + bits(bytes, 8, 5, true)
      chk = checksum(hrp, data)
      "#{hrp}1#{(data + chk).map { |d| CHARSET[d] }.join}"
    end

    def self.checksum(hrp, data)
      values = expanded(hrp) + data + [0, 0, 0, 0, 0, 0]
      poly = pm(values) ^ 1
      (0..5).map { |i| (poly >> (5 * (5 - i))) & 31 }
    end

    def self.expanded(hrp)
      hrp.chars.map { |c| c.ord >> 5 } + [0] + hrp.chars.map { |c| c.ord & 31 }
    end

    def self.pm(values)
      chk = 1
      values.each do |v|
        top = chk >> 25
        chk = ((chk & 0x1ffffff) << 5) ^ v
        5.times { |i| chk ^= GENERATOR[i] if (top >> i).allbits?(1) }
      end
      chk
    end

    def self.bits(data, frombits, tobits, pad)
      acc = 0
      num = 0
      result = []
      maxv = (1 << tobits) - 1
      data.each do |v|
        acc = (acc << frombits) | v
        num += frombits
        while num >= tobits
          num -= tobits
          result << ((acc >> num) & maxv)
        end
      end
      result << ((acc << (tobits - num)) & maxv) if pad && num.positive?
      result
    end

    def initialize(addr)
      @addr = addr.downcase
    end

    def witness
      hrp, data = parse
      raise Sibit::Error, "Invalid Bech32 checksum in '#{@addr}'" unless verified?(hrp, data)
      prog = convert(data[1..-7], 5, 8, false)
      prog.pack('C*').unpack1('H*')
    end

    def version
      _, data = parse
      data[0]
    end

    private

    def parse
      pos = @addr.rindex('1')
      raise Sibit::Error, "Invalid Bech32 address '#{@addr}': no separator" if pos.nil? || pos < 1
      hrp = @addr[0...pos]
      rest = @addr[(pos + 1)..]
      raise Sibit::Error, "Invalid Bech32 address '#{@addr}': data too short" if rest.length < 6
      data = rest.chars.map { |c| CHARSET.index(c) }
      raise Sibit::Error, "Invalid Bech32 character in '#{@addr}'" if data.include?(nil)
      [hrp, data]
    end

    def verified?(hrp, data)
      chk = polymod(expand(hrp) + data)
      [1, 0x2bc830a3].include?(chk)
    end

    def expand(hrp)
      hrp.chars.map { |c| c.ord >> 5 } + [0] + hrp.chars.map { |c| c.ord & 31 }
    end

    def polymod(values)
      chk = 1
      values.each do |v|
        top = chk >> 25
        chk = ((chk & 0x1ffffff) << 5) ^ v
        5.times { |i| chk ^= GENERATOR[i] if (top >> i).allbits?(1) }
      end
      chk
    end

    def convert(data, frombits, tobits, pad)
      acc = 0
      bits = 0
      result = []
      maxv = (1 << tobits) - 1
      data.each do |v|
        acc = (acc << frombits) | v
        bits += frombits
        while bits >= tobits
          bits -= tobits
          result << ((acc >> bits) & maxv)
        end
      end
      result << ((acc << (tobits - bits)) & maxv) if pad && bits.positive?
      result
    end
  end
end
