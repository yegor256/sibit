# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'bigdecimal'
require_relative 'error'

# Sibit main class.
class Sibit
  # An amount of bitcoins, convertible to an exact number of satoshi.
  #
  # It parses the amount through +BigDecimal+ instead of a binary +Float+,
  # so decimal values like 0.29 map to exactly 29,000,000 satoshi. An amount
  # with sub-satoshi precision is rejected instead of being truncated.
  #
  # Author:: Yegor Bugayenko (yegor256@gmail.com)
  # Copyright:: Copyright (c) 2019-2026 Yegor Bugayenko
  # License:: MIT
  class Coins
    def initialize(btc)
      @btc = btc
    end

    def satoshi
      sat = BigDecimal(@btc.to_s) * 100_000_000
      unless sat.frac.zero?
        raise(Sibit::Error, "The amount #{@btc.inspect} is finer than one satoshi")
      end
      Integer(sat)
    rescue ArgumentError, TypeError
      raise(Sibit::Error, "The amount #{@btc.inspect} is not a valid number of bitcoins")
    end
  end
end
